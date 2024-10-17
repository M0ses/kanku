test-kankufiles: centos-current icinga openQA rabbitmq-opensuse simple multivm test-snapshot

centos-current:
	export KANKU_CONFIG=KankuFile.centos-current && kanku destroy && kanku up && kanku destroy
icinga:
	export KANKU_CONFIG=KankuFile.icinga2 && kanku destroy && kanku up && kanku destroy
openQA:
	export KANKU_CONFIG=KankuFile.openQA && kanku destroy && kanku up && kanku destroy
rabbitmq-opensuse:
	export KANKU_CONFIG=KankuFile.rabbitmq-opensuse && kanku destroy && kanku up && kanku destroy
simple:
	export KANKU_CONFIG=KankuFile.simple && kanku destroy && kanku up && kanku destroy
multivm:
	export KANKU_CONFIG=KankuFile.multivm && kanku destroy && kanku up && kanku destroy
test-snapshot:
	export KANKU_CONFIG=KankuFile.test-snapshot && kanku destroy && kanku up && kanku destroy



.PHONY: centos-current icinga openQA rabbitmq-opensuse simple multivm test-snapshot
