require "spec_helper"
require "webmock/rspec"
require "ffaker"

if ENV['CF_V2_RUN_INTEGRATION']
  describe 'A new user tries to use CF against v2 production', :ruby19 => true do
    before(:all) do
      WebMock.allow_net_connect!
    end

    after(:all) do
      WebMock.disable_net_connect!
    end

    let(:target) { ENV['CF_V2_TEST_TARGET'] }
    let(:username) { ENV['CF_V2_TEST_USER'] }
    let(:password) { ENV['CF_V2_TEST_PASSWORD'] }
    let(:organization) { ENV['CF_V2_TEST_ORGANIZATION'] }

    let(:client) do
      client = CFoundry::V2::Client.new("https://#{target}")
      client.login(username, password)
      client
    end

    before do
      Interact::Progress::Dots.start!
    end

    after do
      Interact::Progress::Dots.stop!
    end

    it "registers a new account and deletes it" do
      email = Faker::Internet.email
      BlueShell::Runner.run("#{cf_bin} logout") do |runner|
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} target #{target}") do |runner|
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} login #{username} --password #{password}") do |runner|
        expect(runner).to say(
          "Organization>" => proc {
            runner.send_keys organization
            expect(runner).to say /Switching to organization .*\.\.\. OK/
          },
          "Switching to organization" => proc {}
        )

        expect(runner).to say(
          "Space>" => proc {
            runner.send_keys "1"
            expect(runner).to say /Switching to space .*\.\.\. OK/
          },
          "Switching to space" => proc {}
        )
      end

      BlueShell::Runner.run("#{cf_bin} register #{email} --password p") do |runner|
        expect(runner).to say "Confirm Password>"
        runner.send_keys 'p'
        expect(runner).to say "Your password strength is: good"
        expect(runner).to say "Creating user... OK"
        expect(runner).to say "Authenticating... OK"
      end

      BlueShell::Runner.run("#{cf_bin} logout") do |runner|
        runner.wait_for_exit
      end

      BlueShell::Runner.run("#{cf_bin} login #{username} --password #{password}") do |runner|
        expect(runner).to say "Organization>"
        runner.send_keys "1"
        expect(runner).to say "Space>"
        runner.send_keys "1"
      end

      # TODO: do this when cf delete-user is implemented
      #BlueShell::Runner.run("#{cf_bin} delete-user #{email}") do |runner|
      #  expect(runner).to say "Really delete user #{email}?>"
      #  runner.send_keys "y"
      #  expect(runner).to say "Deleting #{email}... OK"
      #end

      # TODO: not this.
      client.login(email, "p")
      user = client.current_user
      guid = user.guid
      client.login(username, password)
      user.delete!
      client.base.uaa.delete_user(guid)

      BlueShell::Runner.run("#{cf_bin} login #{email} --password p") do |runner|
        expect(runner).to say "Authenticating... FAILED"

        expect(runner).to say "Password>"
        runner.send_keys "another_password"
        expect(runner).to say "Password>"
        runner.send_keys "passwords_for_everyone"
        expect(runner).to say "FAILED"
        runner.output.should_not =~ /CFoundry::/
        runner.output.should_not =~ %r{~/\.cf/crash}
      end
    end
  end
else
  $stderr.puts 'Skipping v2 integration specs; please provide environment variables'
end
