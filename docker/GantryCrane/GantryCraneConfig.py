import ConfigParser
import os
import re
import requests
import sys
from docker import Client as DockerClient
from optparse import OptionParser, OptionGroup


class GantryCraneConfig(object):
    def __init__(self):
        self.options = None
        self.cli_args = None

        self.config = ConfigParser.SafeConfigParser()
        self.option_parser = OptionParser()

        self.init_options()
        (self.options, self.cli_args) = self.option_parser.parse_args()
        self.check_options()
        self.read_config_file()
        self.set_config_from_options()
        self.check_config()

    def check_config(self):
        """
        Check the configuration for acceptable values.
        """
        self.check_config_docker_uri()
        self.check_config_repo_dir()
        self.check_config_project_name()

    def check_config_project_name(self):
        """
        Check if the project name exists, and is a reasonable format.
        """
        if not self.config.has_option('GantryCrane', 'project_name'):
            self.option_parser.print_help()
            print "\nERROR: The project name was not specified! (--project-name)"
            sys.exit(2)

        project_name = self.config.get('GantryCrane', 'project_name')

        if not len(project_name) < 32:
            self.option_parser.print_help()
            print "\nERROR: Project name shoudl be less than 32 characters [A-Za-z0-9._-] (--project-name)"
            sys.exit(2)

        if not re.match("^[A-Za-z0-9._-]*$", project_name):
            self.option_parser.print_help()
            print "\nERROR: Project name may contain only [A-Za-z0-9._-] (--project-name)"
            sys.exit(2)

    def check_config_docker_uri(self):
        """
        Check if the docker socket exists, and is open for connections.
        """
        if not self.config.has_option('GantryCrane', 'docker_uri'):
            self.option_parser.print_help()
            print "\nERROR: The docker URI was not specified! (--docker-uri)"
            sys.exit(2)

        docker_client = DockerClient(self.config.get('GantryCrane', 'docker_uri'))

        try:
            docker_client.info()
        except requests.exceptions.ConnectionError:
            self.option_parser.print_help()
            print "\nERROR: Cannot connect to docker via URI (--docker-uri)"
            sys.exit(2)

    def check_config_repo_dir(self):
        """
        Check if the repo dir seems to be a Docker driven project.
        """
        if not self.config.has_option('GantryCrane', 'repo_dir'):
            self.option_parser.print_help()
            print "\nERROR: The project repository was not specified! (--repo-dir)"
            sys.exit(2)

        repo_dir = self.config.get('GantryCrane', 'repo_dir')

        if not os.path.exists(repo_dir) or not os.path.exists(os.path.join(repo_dir, 'Dockerfile')):
            self.option_parser.print_help()
            print "\nERROR: The project repository does not seem to be valid! (--repo-dir)"
            sys.exit(2)

    def check_options(self):
        """
        Check the CLI options for acceptable values.
        """
        self.check_options_config_file()

    def check_options_config_file(self):
        """
        Check if the configuration file specified exists.
        """
        if self.options.config_filepath is None or not os.path.exists(self.options.config_filepath):
            self.option_parser.print_help()
            print "\nERROR: Cannot read configuration file! (--config)"
            sys.exit(2)

    def init_options(self):
        """
        Initialize the CLI options.
        """
        group = OptionGroup(self.option_parser, 'GantryCrane')

        group.add_option(
            "-g", "--gantry-config",
            dest="config_filepath",
            default='',
            help="The full path to the GantryCrane configuration file to use.",
        )
        group.add_option(
            "-d", "--repo-dir",
            dest="repo_dir",
            default='',
            help="The directory containing the repository to deploy.",
        )
        group.add_option(
            "-n", "--project-name",
            dest="project_name",
            default='',
            help="The name of the project to deploy, typically the URI.",
        )
        group.add_option(
            "-u", "--docker-uri",
            dest="docker_uri",
            default='',
            help="The protocol+hostname+port where the Docker server is hosted.",
        )

        self.option_parser.add_option_group(group)

    def read_config_file(self):
        """
        Read the configuration file.
        """
        self.config.read(self.options.config_filepath)

    def set_config_from_options(self):
        """
        CLI options must trump config file values, so override any config values with options provided.
        """
        for option_key, option_value in self.options.__dict__.items():
            if option_value is not '':
                self.config.set('GantryCrane', option_key, option_value)
