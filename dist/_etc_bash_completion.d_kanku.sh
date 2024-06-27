#!/bin/bash

# Built with MooseX::App::Plugin::BashCompletion::Command on 2024/06/27

kanku_COMMANDS='help api ca check_configs console db destroy init ip list login logout lsi pfwd rabbit rcomment retrigger rguest rguest console rguest list rguest ssh rhistory rjob rjobgroup rr rtrigger rworker setup snapshot ssh startui startvm status stopui stopvm up urlwrapper'

_kanku_macc_help() {
    if [ $COMP_CWORD = 2 ]; then
        _kanku_compreply "$kanku_COMMANDS"
    else
        COMPREPLY=()
    fi
}

_kanku_macc_api() {
    _kanku_compreply "--apiurl -a --as_admin --aa --data --details -d --help -h --usage -? --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_ca() {
    _kanku_compreply "--ca_path -p --create -c --force -f --help -h --usage -? --traceback -t"
}

_kanku_macc_check_configs() {
    _kanku_compreply "--devel -d --help -h --usage -? --jobs -j --server -s --traceback -t"
}

_kanku_macc_console() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --log_file --log_stdout --traceback -t"
}

_kanku_macc_db() {
    _kanku_compreply "--dbfile --dbpass -P --dbuser -U --devel -d --dsn --help -h --usage -? --homedir --install -i --server --share_dir --status -s --traceback -t --upgrade -u"
}

_kanku_macc_destroy() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --keep_volumes --log_file --log_stdout --traceback -t"
}

_kanku_macc_init() {
    _kanku_compreply "--apiurl -a --box -b --default_job -j --domain_name -d --force -f --help -h --usage -? --memory -m --output -o -F --package --pkg --pool --project --prj --repository --repo --template -T --traceback -t --vcpu -c"
}

_kanku_macc_ip() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --log_file --log_stdout --login_pass -p --login_user -u --traceback -t"
}

_kanku_macc_list() {
    _kanku_compreply "--global -g --help -h --usage -? --traceback -t"
}

_kanku_macc_login() {
    _kanku_compreply "--apiurl -a --as_admin --aa --help -h --usage -? --keyring -k --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_logout() {
    _kanku_compreply "--apiurl -a --as_admin --aa --help -h --usage -? --keyring -k --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_lsi() {
    _kanku_compreply "--apiurl -a --help -h --usage -? --name -n --project -p --traceback -t"
}

_kanku_macc_pfwd() {
    _kanku_compreply "--domain_name -d --help -h --usage -? --interface -i --ports -p --traceback -t"
}

_kanku_macc_rabbit() {
    _kanku_compreply "--config -c --help -h --usage -? --listen -l --notification -n --output_plugin -o --props -p --send -s --traceback -t"
}

_kanku_macc_rcomment() {
    _kanku_compreply "--apiurl -a --as_admin --aa --comment_id -C --create -c --delete -D --details -d --help -h --usage -? --job_id -j --keyring -k --list -l --message -m --modify -M --password -p --rc_file --show -s --traceback -t --user -u"
}

_kanku_macc_retrigger() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --help -h --usage -? --job -j --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_rguest() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --domain --execute -e --help -h --usage -? --host --keyring -k --list -l --password -p --rc_file --ssh_user -U --ssh-user --state -S --traceback -t --user -u"
}

_kanku_macc_rguest_console() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --domain --execute -e --help -h --usage -? --host --keyring -k --list -l --password -p --rc_file --ssh_user -U --ssh-user --traceback -t --user -u"
}

_kanku_macc_rguest_list() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --domain --help -h --usage -? --host --keyring -k --list -l --password -p --rc_file --state -S --traceback -t --user -u"
}

_kanku_macc_rguest_ssh() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --domain --execute -e --help -h --usage -? --host --keyring -k --list -l --password -p --rc_file --ssh_user -U --ssh-user --traceback -t --user -u"
}

_kanku_macc_rhistory() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --full --help -h --usage -? --job_name --keyring -k --latest --limit --list -l --page --password -p --rc_file --state --traceback -t --user -u --worker"
}

_kanku_macc_rjob() {
    _kanku_compreply "--apiurl -a --as_admin --aa --config -c --details -d --filter -f --help -h --usage -? --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_rjobgroup() {
    _kanku_compreply "--apiurl -a --as_admin --aa --config -c --details -d --filter -f --help -h --usage -? --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_rr() {
    _kanku_compreply "--apiurl -a --as_admin --aa --help -h --usage -? --keyring -k --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_rtrigger() {
    _kanku_compreply "--apiurl -a --as_admin --aa --config -c --details -d --help -h --usage -? --job -j --job_group -J --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_rworker() {
    _kanku_compreply "--apiurl -a --as_admin --aa --details -d --help -h --usage -? --keyring -k --list -l --password -p --rc_file --traceback -t --user -u"
}

_kanku_macc_setup() {
    _kanku_compreply "--apache --apiurl --devel --dns_domain_name --dsn --help -h --usage -? --images_dir --interactive -i --master --mq_host --mq_pass --mq_user --mq_vhost --osc_pass --osc_user --ovs_ip_prefix --server --distributed --ssl --traceback -t --user --worker"
}

_kanku_macc_snapshot() {
    _kanku_compreply "--create -c --domain_name -d --file --help -h --usage -? --list -l --log_file --log_stdout --name -n --remove -r --revert -R --traceback -t"
}

_kanku_macc_ssh() {
    _kanku_compreply "--agent_forward -A --domain_name -d --execute -e --file --help -h --usage -? --ipaddress -i --log_file --log_stdout --pseudo_terminal -T --timeout --traceback -t --user -u --x11_forward -X"
}

_kanku_macc_startui() {
    _kanku_compreply "--help -h --usage -? --traceback -t"
}

_kanku_macc_startvm() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --log_file --log_stdout --traceback -t"
}

_kanku_macc_status() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --log_file --log_stdout --traceback -t"
}

_kanku_macc_stopui() {
    _kanku_compreply "--help -h --usage -? --traceback -t"
}

_kanku_macc_stopvm() {
    _kanku_compreply "--domain_name -d --file --force -f --help -h --usage -? --log_file --log_stdout --traceback -t"
}

_kanku_macc_up() {
    _kanku_compreply "--domain_name -d --file --help -h --usage -? --job_name -j --log_file --log_stdout --offline -o --pool -p --skip_all_checks --skip_check_domain -S --skip_check_package --skip_check_project --traceback -t"
}

_kanku_macc_urlwrapper() {
    _kanku_compreply "--help -h --usage -? --outdir -d --traceback -t --url -u"
}

_kanku_compreply() {
    COMPREPLY=($(compgen -W "$1" -- ${COMP_WORDS[COMP_CWORD]}))
}

_kanku_macc() {
    case $COMP_CWORD in
        0)
            ;;
        1)
            _kanku_compreply "$kanku_COMMANDS"
            ;;
        *)
            eval _kanku_macc_${COMP_WORDS[1]}

    esac
}

complete -o default -F _kanku_macc kanku


