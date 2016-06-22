#!/usr/bin/env python
from GantryCrane.GantryCrane import GantryCrane
from GantryCrane.GantryCrane import GantryCraneContainer

deploy = GantryCrane()

main_container = GantryCraneContainer(
    name=deploy.project_name,
    repo_dir=deploy.repo_dir
)

main_container.add_port_bindings(
    {
        3207: 80,
    }
)

main_container.add_environment_vars(
    {
        'MYSQL_ALLOW_EMPTY_PASSWORD': 'TRUE',
    }
)

deploy.add_container(main_container)



mysql_container = GantryCraneContainer(
    name=deploy.project_name + '_mysql',
    image_name='mysql',
    image_tag='5.6'
)

mysql_container.add_port_bindings(
    {
        3208: 80,
    }
)

mysql_container.add_environment_vars(
    {
        'MYSQL_ALLOW_EMPTY_PASSWORD': 'TRUE',
    }
)

deploy.add_container(mysql_container)


deploy.deploy()
