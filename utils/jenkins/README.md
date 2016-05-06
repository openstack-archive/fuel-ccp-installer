Examples testing
================

To automatically test examples install first fuel-devops framework. Installation process is described here https://github.com/openstack/fuel-devops. After installation run migrations scripts:

```bash
export DJANGO_SETTINGS_MODULE=devops.settings
django-admin.py syncdb
django-admin.py migrate
```

To test examples run one of available test scripts. You need to run it from solar main dir, for example:

```
./utils/jenkins/run_hosts_example.sh
```
