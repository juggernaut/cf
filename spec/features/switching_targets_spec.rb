require "spec_helper"

if ENV['CF_V2_RUN_INTEGRATION']
  describe 'A new user tries to use CF against v2 production', :ruby19 => true do

    let(:target) { ENV['CF_V2_TEST_TARGET'] }
    let(:username) { ENV['CF_V2_TEST_USER'] }
    let(:password) { ENV['CF_V2_TEST_PASSWORD'] }
    let(:space) { ENV['CF_V2_TEST_SPACE'] }
    let(:space2) { "#{ENV['CF_V2_TEST_SPACE']}-2"}
    let(:organization) { ENV['CF_V2_TEST_ORGANIZATION'] }

    before do
      Interact::Progress::Dots.start!
    end

    after do
      Interact::Progress::Dots.stop!
    end

    it "can switch targets, even if a target is invalid" do
      BlueShell::Runner.run("#{cf_bin} target invalid-target") do |runner|
        expect(runner).to say "Target refused"
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} target #{target}") do |runner|
        expect(runner).to say "Setting target"
        expect(runner).to say target
        runner.wait_for_exit
      end
    end

    it "can switch organizations and spaces" do
      BlueShell::Runner.run("#{cf_bin} logout") do |runner|
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} login") do |runner|
        expect(runner).to say "Email>"
        runner.send_keys username

        expect(runner).to say "Password>"
        runner.send_keys password

        expect(runner).to say "Authenticating... OK"
      end

      BlueShell::Runner.run("#{cf_bin} target -o #{organization}") do |runner|
        expect(runner).to say("Switching to organization #{organization}")

        expect(runner).to say("Space>")
        runner.send_keys space2

        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} target -s #{space}") do |runner|
        expect(runner).to say("Switching to space #{space}")
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} target -s #{space2}") do |runner|
        expect(runner).to say("Switching to space #{space2}")
        runner.wait_for_exit
      end
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide necessary environment variables'
end
