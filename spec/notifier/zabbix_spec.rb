require "spec_helper"

module Backup
  describe Notifier::Zabbix do
    let(:model) { Model.new(:test_trigger, "test label") }
    let(:notifier) { Notifier::Zabbix.new(model) }

    before do
      allow(Utilities).to receive(:utility).with(:zabbix_sender).and_return("zabbix_sender")
      allow(Config).to receive(:hostname).and_return("zabbix.hostname")
    end

    it_behaves_like "a class that includes Config::Helpers"
    it_behaves_like "a subclass of Notifier::Base"

    describe "#initialize" do
      it "provides default values" do
        expect(notifier.zabbix_host).to eq "zabbix.hostname"
        expect(notifier.zabbix_port).to be 10_051
        expect(notifier.service_name).to eq "Backup test_trigger"
        expect(notifier.service_host).to eq "zabbix.hostname"
        expect(notifier.item_key).to eq "backup_status"

        expect(notifier.on_success).to be(true)
        expect(notifier.on_warning).to be(true)
        expect(notifier.on_failure).to be(true)
        expect(notifier.max_retries).to be(10)
        expect(notifier.retry_waitsec).to be(30)
      end

      it "configures the notifier" do
        notifier = Notifier::Zabbix.new(model) do |zabbix|
          zabbix.zabbix_host  = "my_zabbix_server"
          zabbix.zabbix_port  = 1234
          zabbix.service_name = "my_service_name"
          zabbix.service_host = "my_service_host"
          zabbix.item_key     = "backup_status"

          zabbix.on_success    = false
          zabbix.on_warning    = false
          zabbix.on_failure    = false
          zabbix.max_retries   = 5
          zabbix.retry_waitsec = 10
        end

        expect(notifier.zabbix_host).to eq "my_zabbix_server"
        expect(notifier.zabbix_port).to be 1234
        expect(notifier.service_name).to eq "my_service_name"
        expect(notifier.service_host).to eq "my_service_host"
        expect(notifier.item_key).to eq "backup_status"
        expect(notifier.on_success).to be(false)
        expect(notifier.on_warning).to be(false)
        expect(notifier.on_failure).to be(false)
        expect(notifier.max_retries).to be(5)
        expect(notifier.retry_waitsec).to be(10)
      end
    end # describe '#initialize'

    describe "#notify!" do
      before do
        notifier.service_host = "my.service.host"
        allow(model).to receive(:duration).and_return("12:34:56")
        allow(notifier).to receive(:zabbix_port).and_return(10_051)
      end

      context "when status is :success" do
        let(:zabbix_msg) do
          "my.service.host\tBackup test_trigger\t0\t"\
          "[Backup::Success] test label (test_trigger)"
        end

        let(:zabbix_cmd) do
          "zabbix_sender -z 'zabbix.hostname'" \
          " -p '#{notifier.zabbix_port}'" \
          " -s #{notifier.service_host}" \
          " -k #{notifier.item_key}" \
          " -o '#{zabbix_msg}'"
        end

        before { allow(model).to receive(:exit_status).and_return(0) }

        it "sends a Success message" do
          expect(Utilities).to receive(:run).with(zabbix_cmd)
          notifier.send(:notify!, :success)
        end
      end

      context "when status is :warning" do
        let(:zabbix_msg) do
          "my.service.host\tBackup test_trigger\t1\t"\
          "[Backup::Warning] test label (test_trigger)"
        end

        let(:zabbix_cmd) do
          "zabbix_sender -z 'zabbix.hostname'" \
          " -p '#{notifier.zabbix_port}'" \
          " -s #{notifier.service_host}" \
          " -k #{notifier.item_key}" \
          " -o '#{zabbix_msg}'"
        end

        before { allow(model).to receive(:exit_status).and_return(1) }

        it "sends a Warning message" do
          expect(Utilities).to receive(:run).with(zabbix_cmd)
          notifier.send(:notify!, :warning)
        end
      end

      context "when status is :failure" do
        let(:zabbix_msg) do
          "my.service.host\tBackup test_trigger\t2\t"\
          "[Backup::Failure] test label (test_trigger)"
        end

        let(:zabbix_cmd) do
          "zabbix_sender -z 'zabbix.hostname'" \
          " -p '#{notifier.zabbix_port}'" \
          " -s #{notifier.service_host}" \
          " -k #{notifier.item_key}" \
          " -o '#{zabbix_msg}'"
        end

        before { allow(model).to receive(:exit_status).and_return(2) }

        it "sends a Failure message" do
          expect(Utilities).to receive(:run).with(zabbix_cmd)
          notifier.send(:notify!, :failure)
        end
      end
    end # describe '#notify!'
  end
end
