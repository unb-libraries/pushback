from docker import Client as DockerClient
from GantryCraneConfig import GantryCraneConfig


class GantryCraneContainer(object):
    def __init__(self, name, repo_dir=None, image_name=None, image_tag=None):
        self.name = name
        self.id = None
        self.ports = []
        self.port_bindings = {}
        self.volumes = []
        self.environment = {}
        self.image_name = image_name
        self.image_tag = image_tag
        self.repo_dir = repo_dir

    def add_port_bindings(self, port_bindings):
        for host_port, container_port in port_bindings.iteritems():
            self.ports.append(host_port)
            self.port_bindings[container_port] = host_port

    def add_environment_vars(self, environment_vars):
        for var_name, value in environment_vars.iteritems():
            self.environment[var_name] = value

    def add_volumes(self, volumes):
        self.volumes.extend(volumes)


class GantryCrane(object):
    def __init__(self):
        self.cli = None
        self.containers = []
        self.config = None
        self.network = None

        self.init_config()
        self.project_name = self.config.get('GantryCrane', 'project_name')
        self.repo_dir = self.config.get('GantryCrane', 'repo_dir')
        self.connect()

    def add_container(self, container):
        self.containers.append(container)

    def build_all(self):
        for container in self.containers:
            if container.repo_dir is not None:
                self.cli.build(
                    path=container.repo_dir,
                    rm=True,
                    pull=True,
                    tag=container.name
                )

    def init_config(self):
        tmp_config = GantryCraneConfig()
        self.config = tmp_config.config

    def connect(self):
        self.cli = DockerClient(
            self.config.get('GantryCrane', 'docker_uri')
        )

    def create_network(self):
        if len(self.cli.networks(names=[self.project_name])) == 0:
            print "Creating Network"
            self.cli.create_network(
                name=self.project_name,
                driver='bridge'
            )

    def remove_network(self):
        if self.project_name in self.cli.networks():
            self.cli.remove_network(net_id=self.project_name)

    def deploy(self):
        self.create_network()
        self.build_all()
        for container in self.containers:
            print "Removing Existing"
            self.remove_existing(container)
            self.create(container)
            print "Connecting to Network"
            self.connect_to_network(container)
            print "Starting"
            self.start(container)

    def create(self, container):
        if container.repo_dir is not None:
            container_image = container.name
        else:
            container_image = container.image_name + ':' + container.image_tag
            print "Pulling Image"
            self.cli.pull(repository=container.image_name, tag=container.image_tag)
        print "Creating Container"
        container.id = self.cli.create_container(
            image=container_image,
            name=container.name,
            ports=container.ports,
            host_config=self.cli.create_host_config(
                port_bindings=container.port_bindings
            ),
            environment=container.environment,
            volumes=container.volumes
        )

    def connect_to_network(self, container):
        self.cli.connect_container_to_network(
            container=container.name,
            net_id=self.project_name
        )

    def remove_existing(self, container):
        if len(self.cli.containers(quiet=False, all=True, filters={'name': container.name})) > 0:
            print "Removing image"
            self.cli.remove_container(
                container=container.name,
                force=True
            )

    def start(self, container):
        self.cli.start(container.id)
