require 'pdksync'
require 'spec_helper'
require 'git'
require 'fileutils'
require 'octokit'

describe PdkSync do
  before(:all) do
    @pdksync_dir = './modules_pdksync'
    @pdksync_gem_dir = './gems_pdksync'
    module_name = 'puppetlabs-motd'
    gem_name = 'puppet-strings'
    @module_names = ['puppetlabs-motd']
    @output_path_module = "#{@pdksync_dir}/#{module_name}"
    @output_path_gem = "#{@pdksync_gem_dir}/#{gem_name}"
    @folder = Dir.pwd
    # Make changes to modules_managed.yaml file
    text = File.read('managed_modules.yml')
    new_contents = text.gsub(%r{#- puppetlabs-motd$}, '- puppetlabs-motd')
    File.open('managed_modules.yml', 'w') { |file| file.puts new_contents }
  end

  let(:platform) { Object.new }

  before(:each) do
    allow(ENV).to receive(:[]).with('HOME').and_return('./')
    allow(ENV).to receive(:[]).with('GIT_DIR').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_WORK_TREE').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_INDEX_FILE').and_return(nil)
    allow(ENV).to receive(:[]).with('PDKSYNC_LOG_FILENAME').and_return(nil)
    allow(ENV).to receive(:[]).with('LOG_LEVEL').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_SSH').and_return(nil)
    allow(ENV).to receive(:[]).with('GIT_PATH').and_return(nil)
    allow(ENV).to receive(:[]).with('GITHUB_TOKEN').and_return('blah')
    allow(ENV).to receive(:[]).with('GEMFURY_TOKEN').and_return('blah')
    allow(ENV).to receive(:[]).with('PDKSYNC_VERSION_CHECK').and_return(nil)
    allow(ENV).to receive(:[]).with('http_proxy').and_return(nil)
    allow(ENV).to receive(:[]).with('HTTP_PROXY').and_return(nil)
    allow(ENV).to receive(:[]).with('PDKSYNC_CONFIG_PATH').and_return(nil)
    allow(ENV).to receive(:[]).with('TERM').and_return(nil)
    allow(ENV).to receive(:[]).with('NO_COLOR').and_return(nil)
    allow(PdkSync::Utils).to receive(:return_modules).and_return(@module_names)
    allow(PdkSync::Utils).to receive(:validate_modules_exist).and_return(@module_names)
    allow(PdkSync::Utils).to receive(:setup_client).and_return(git_client)
    Dir.chdir(@folder)
    allow(PdkSync::GitPlatformClient).to receive(:new).and_return(platform)
    allow(Octokit).to receive(:tags).with('puppetlabs/pdk').and_return([{ name: '1' }])
    allow(PdkSync::Utils.configuration).to receive(:git_base_uri).and_return('https://github.com')
  end

  let(:git_client) do
    double(PdkSync::GitPlatformClient)
  end

  context 'main method' do
    it 'runs clone sucessfully' do
      allow(PdkSync::Utils).to receive(:setup_client).and_return(git_client)
      FileUtils.rm_rf(@pdksync_dir)
      PdkSync::Utils.create_filespace
      PdkSync.main(steps: [:clone])
      expect(Dir.exist?(@pdksync_dir)).to be(true)
      expect(Dir.exist?(@output_path_module)).to be(true)
    end

    it 'runs pdk convert, and files have changed' do
      PdkSync.main(steps: [:pdk_convert])
      File.exist?("#{@output_path_module}/convert_report.txt")
    end

    it 'raise when running a command with no argument' do
      expect { PdkSync.main(steps: [:run_a_command]) }.to raise_error(RuntimeError, %r{"run_a_command" requires an argument to run.})
    end

    it 'runs a command "touch cat.meow"' do
      PdkSync.main(steps: [:run_a_command], args: { command: 'touch cat.meow' })
      expect File.exist?("#{@output_path_module}/cat.meow")
    end

    it 'raise when create_commit with no arguments' do
      expect { PdkSync.main(steps: [:create_commit]) }.to raise_error(RuntimeError, %r{Needs a branch_name and commit_message})
    end

    it 'raise when create_pr with no arguments' do
      expect { PdkSync.main(steps: [:create_pr]) }.to raise_error(RuntimeError, %r{Needs a pr_title})
    end

    it 'create_pr with 1 argument' do
      expect { PdkSync.main(steps: [:create_pr], args: { pr_title: 'some title' }) }.to_not raise_error
    end

    it 'raise when clean_branches with no arguments' do
      expect { PdkSync.main(steps: [:clean_branches]) }.to raise_error(RuntimeError, %r{Needs a branch_name, and the branch name contains the string pdksync})
    end

    it 'raise when gem_file_update with no arguments' do
      expect { PdkSync.main(steps: [:gem_file_update]) }.to raise_error(NoMethodError)
    end
    it 'gem_file_update runs with invalid gem_line given' do
      expect { PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus', gem_line: "gem 'puppet_litmus'\, git: 'https://github.com/test/puppet_litmus.git'" }) }. to raise_error(Errno::ENOENT) # rubocop:disable Metrics/LineLength
    end
    it 'gem_file_update runs with invalid gem_sha_replacer' do
      expect { PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus', gem_sha_finder: 'jsjsjsjsjsjsjs', gem_sha_replacer: 'abcdefgjhkk' }) }.to raise_error(RuntimeError) # , ("Couldn't find sha: abcdefgjhkk in your repository: puppet_litmus")) # rubocop:disable Metrics/LineLength
    end
    it 'gem_file_update runs with invalid gem_version_replacer' do
      expect { PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus', gem_version_finder: '<= 0.4.9', gem_version_replacer: '<= 1.4.11' }) }.to raise_error(RuntimeError) # , ("Couldn't find version: 1.4.11 in your repository: puppet_litmus")) # rubocop:disable Metrics/LineLength
    end
    it 'gem_file_update runs with invalid gem_branch_replacer' do
      expect { PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus', gem_branch_finder: 'jsjsjsjsjsjsjs', gem_branch_replacer: 'abcdefgjhkk' }) }.to raise_error(RuntimeError) # , "Couldn't find branch: abcdefgjhkk in your repository: puppet_litmus") # rubocop:disable Metrics/LineLength
    end
    it 'raise when run_tests with no arguments' do
      expect { PdkSync.main(steps: [:run_tests_locally]) }.to raise_error(NoMethodError) # , %r{run_tests" requires arguments (module_type) to run.})
    end
    it 'raise when litmusacceptance.out does not exist' do
      expect { PdkSync::Utils.fetch_test_results_locally('modules_pdksync/puppetlabs-motd', 'litmus', 'puppetlabs-motd', []) }.to raise_error(RuntimeError, %r{FATAL - File modules_pdksync/puppetlabs-motd/litmusacceptance.out does not exist.})
    end
    it 'raise when run_tests_jenkins with no arguments' do
      allow(ENV).to receive(:[]).with('JENKINS_USERNAME').and_return('JENKINS_USERNAME')
      allow(ENV).to receive(:[]).with('JENKINS_PASSWORD').and_return('JENKINS_PASSWORD')
      expect { PdkSync.main(steps: [:run_tests_jenkins], args: {}) }.to raise_error(RuntimeError) # , "run_tests_jenkins requires arguments (github_repo, github_branch) to run"
    end
    it 'raise errors without jenkins credentials' do
      allow(ENV).to receive(:[]).with('JENKINS_USERNAME').and_return(nil)
      allow(ENV).to receive(:[]).with('JENKINS_PASSWORD').and_return(nil)
      expect { PdkSync.main(steps: [:run_tests_jenkins], args: { jenkins_server_url: 'https//jenkins.com', github_repo: 'test', github_branch: 'test' }) }.to raise_error(RuntimeError, %r{Jenkins access token for Jenkins not set})
    end

    describe 'gem_file_update with valid values' do
      before(:all) do
        PdkSync.main(steps: [:gem_file_update], args: {
                       gem_to_test: 'puppet_litmus',
                       gem_line: "gem 'puppet_litmus'\, git: 'https://github.com/puppetlabs/puppet_litmus.git'\, branch: 'main'\, ref: '04da90638f5b5fd7f007123c8c0cc551c8cb3e54'\, '=0.1.0'"
                     })
      end
      it 'gem_file_update with valid gem_branch_replacer' do
        PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus',
                                                        gem_branch_finder: 'master', gem_branch_replacer: 'main' })
        expect(File.read('Gemfile')).to match(%r{main})
      end
      it 'gem_file_update runs, and contains the gem_sha given' do
        PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus',
                                                        gem_sha_finder: '04da90638f5b5fd7f007123c8c0cc551c8cb3e54', gem_sha_replacer: '95ed1c62ffcf89003eb0fe9d66989caa45884538' })
        expect(File.read('Gemfile')).to match(%r{95ed1c62ffcf89003eb0fe9d66989caa45884538})
      end
      it 'gem_file_update runs, and contains the gem_version given' do
        PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus',
                                                        gem_version_finder: '=0.1.0', gem_version_replacer: '<=0.3.0' })
        expect(File.read('Gemfile')).to match(%r{0.3.0})
      end
      it 'gem_file_update with valid gem_line' do
        PdkSync.main(steps: [:gem_file_update], args: { gem_to_test: 'puppet_litmus',
                                                        gem_line: "gem 'puppet_litmus'\, git: 'https://github.com/puppetlabs/puppet_litmus.git'" })
        expect(File.read('Gemfile')).to match(%r{gem 'puppet_litmus', git: 'https://github.com/puppetlabs/puppet_litmus.git'})
      end
      it 'multigem updated in the module gemfile' do
        PdkSync.main(steps: [:multi_gemfile_update], args: { gem_name: 'puppet-module', gemfury_username: 'tester' })
        expect File.exist?("#{@output_path_module}/Gemfile")
      end
    end
  end
  context 'main method' do
    let(:platform) { Object.new }

    it 'runs clone gem sucessfully' do
      allow(PdkSync::Utils).to receive(:setup_client).and_return(git_client)
      FileUtils.rm_rf(@pdksync_gem_dir)
      PdkSync::Utils.create_filespace_gem
      PdkSync.main(steps: [:clone_gem], args: { gem_name: 'puppet-strings' })
      expect(Dir.exist?(@pdksync_dir)).to be(true)
      expect(Dir.exist?(@pdksync_gem_dir)).to be(true)
      expect(Dir.exist?(@output_path_gem)).to be(true)
    end
    it 'raise when running a command with no argument' do
      expect { PdkSync.main(steps: [:multi_gem_testing]) }.to raise_error(RuntimeError, %r{"multi_gem_testing" requires arguments to run version_file and build_gem})
    end
    it 'runs a command for updating the version and building the gem' do
      allow(Octokit).to receive(:tags).with('puppetlabs/puppet-strings').and_return([{ name: '1' }])
      PdkSync.main(steps: [:multi_gem_testing], args: { gem_name: 'puppet-strings', version_file: 'lib/puppet-strings/version.rb', build_gem: 'rake build', gem_path: 'pkg', gem_username: 'tester' })
      expect File.exist?("#{@output_path_gem}/pkg")
    end
  end
  after(:all) do
    # Make changes to modules_managed.yaml file
    Dir.chdir(@folder)
    text = File.read('managed_modules.yml')
    new_contents = text.gsub(%r{- puppetlabs-motd$}, '#- puppetlabs-motd')
    File.open('managed_modules.yml', 'w') { |file| file.puts new_contents }
  end
end
