# -*- coding: utf-8 -*-
#
# Copyright (c) 2015, Alcatel-Lucent Inc
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of the copyright holder nor the names of its contributors
#       may be used to endorse or promote products derived from this software without
#       specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import os
import commands
from optparse import OptionParser
import sys

ROOT_DIRECTORY = os.path.join(os.path.dirname(os.path.realpath(__file__)), "..", "..", "..", "..")

# Utilities


def command(command, title=None, expected=0):
    """
        Runs a shell command.

        If the command doesn't return the expected return code, the script will die

        Args:
            command: the command to run
            title: if set, will display only the title, otherwise, it will be generated
            expected: the return value of the command that will be considered as a success (default: 0)
    """

    if title:
        print "# %s" % title
    else:
        print "\033[35m# Running: %s in %s \033[0m" % (command, os.getcwd())

    ret = os.system(command)

    if not ret == expected:
        print "\033[31mERROR: Command expected to return %d (was %d)\033[0m" % (expected, ret)
        sys.exit(-1)
    else:
        print "\033[32mSUCCESS\033[0m"

    return ret


def init(install_dir, build_dir):
    """
        Performs some initialization
    """
    try:
        os.makedirs(build_dir)
    except:
        pass
    os.environ["JAVA_OPTS"] = "-Xmx1024M"
    os.environ["CAPP_BUILD"] = build_dir
    os.environ["CAPP_NOSUDO"] = "1"
    os.environ["PATH"] = "%s:%s" % (os.environ["PATH"], "%s/bin" % install_dir)

    if "NARWHAL_ENGINE" not in os.environ:
        if "darwin" not in sys.platform:
            os.environ["NARWHAL_ENGINE"] = "rhino"
        else:
            os.environ["NARWHAL_ENGINE"] = "jsc"


# Libraries Management

def build_library(name, custom_command=None):
    """
        Builds a library

        Args:
            name: the name of the library (that will be found in Libraries folder)
            custom_command: by default, the build command will be jake release; jake debug. Set this to change it
    """
    os.environ["OBJJ_INCLUDE_PATHS"] = "%s/Frameworks" % ROOT_DIRECTORY
    current_path = os.getcwd()
    os.chdir("Libraries/%s" % name)

    if custom_command is None:
        command(command="jake release; jake debug")
    else:
        command(command=custom_command)

    os.chdir(current_path)
    command(command="capp gen -fl --force -F %s ." % name)


def clean_library(name):
    """
        Cleans a library

        Args:
            name: the name of the library to clean
    """
    current_path = os.getcwd()
    os.chdir("Libraries/%s" % name)
    command(command="jake clean")
    os.chdir(current_path)


# Theme Management

def build_theme(name):
    """
        Builds a Theme

        Args:
            name: the name of the theme. (that will be found in the Libraries folder)
    """
    os.environ["OBJJ_INCLUDE_PATHS"] = "%s/Frameworks" % ROOT_DIRECTORY
    current_path = os.getcwd()
    os.chdir("Libraries/%s" % name)
    command(command="jake build")
    os.chdir(current_path)
    command(command="capp gen -fl --force -T %s ." % name)


def clean_theme(name):
    """
        Cleans a Theme

        Args:
            name: the name of the theme to clean
    """
    current_path = os.getcwd()
    os.chdir("Libraries/%s" % name)
    command(command="rm -rf Build")
    os.chdir(current_path)


# Cappuccino Management

def install_cappuccino(install_dir, local_distrib):
    """
        Installs Cappuccino

        Args:
            install_dir: where to install cappuccino
            build_dir: where to build cappuccino
            local_distrib: the path of a local bootstrapped cappuccino archive
    """
    current_path = os.getcwd()
    os.chdir("Libraries/Cappuccino")
    command(command="rm -rf %s" % install_dir)

    if os.path.exists(local_distrib):
        command(command="./bootstrap.sh --noprompt --directory %s --copy-local %s" % (install_dir, local_distrib))
    else:
        command(command="./bootstrap.sh --noprompt --directory %s" % install_dir)
    command(command="jake install")

    os.chdir(current_path)


def clean_cappuccino(install_dir, build_dir):
    """
        Cleans Cappuccino installation

        Args:
            install_dir: where cappuccino is installed
            build_dir: where cappuccino is built
    """
    command(command="jake clobber-theme; jake clobber")
    command(command="rm -rf '%s'" % install_dir)
    command(command="rm -rf '%s'" % build_dir)


# WAR Management

def build_war(name):
    """
        Builds a war file

        Args:
            name: name of the war file
    """
    target = "Deployment"

    if "ARCHITECT_BUILD_DEBUG" in os.environ:
        name = "%s-debug" % name
        target = "Debug"

    current_path = os.getcwd()
    os.chdir("./webapp")
    command(command="unzip /var/archive/supplement/visualization_framework/build.zip")
    os.rename("build", "reports")
    command(command="jar -cf %s.war ." % name)
    command(command="mv %s.war ../Build/%s/" % (name, target))
    os.chdir(current_path)


def clean_war():
    """
        Cleans the war file
    """

    current_path = os.getcwd()
    os.chdir("./webapp")
    command(command="rm -rf Application.js *.environment Frameworks Info.plist Resources index.html")
    os.chdir(current_path)


# Project Management

def build_project(build_version="dev"):
    """
        Builds the main project

        Args:
            build_version: the build version string (eg. 1.2-dev)
    """
    git_rev = commands.getoutput("git log --pretty=format:'%h' -n 1")
    git_branch = commands.getoutput("git symbolic-ref HEAD").split("/")[-1]

    if "ARCHITECT_BUILD_DEBUG" in os.environ:
        build_version = "%s-debug" % build_version

    f = open("Resources/app-version.js", "w")
    f.write("APP_GITVERSION = '%s-%s'\nAPP_BUILDVERSION='%s'\n" % (git_branch, git_rev, build_version))
    f.close()
    command(command="capp gen -fl . --force")

    if "ARCHITECT_BUILD_DEBUG" in os.environ:
        command(command="jake devdeploy")
    else:
        command(command="jake deploy")


def clean_project():
    """
        Cleans the main project
    """
    command(command="rm -rf Build")


# Main Function

def perform_build(additional_libraries=[], additional_themes=[], war_name="ui"):
    """
    """

    parser = OptionParser()
    parser.add_option("-c", "--cappuccino",
                      dest="cappuccino",
                      action="store_true",
                      help="Build and install Cappuccino")
    parser.add_option("-t", "--tnkit",
                      dest="tnkit",
                      action="store_true",
                      help="Build and install TNKit")
    parser.add_option("-b", "--bambou",
                      dest="bambou",
                      action="store_true",
                      help="Build and install Bambou")
    parser.add_option("-k", "--nukit",
                      dest="nukit",
                      action="store_true",
                      help="Build and deploy NUKit")

    for library in additional_libraries:
        parser.add_option("-%s" % library["short_arg"], "--%s" % library["name"].lower(),
                          dest=library["name"].lower(),
                          action="store_true",
                          help="Build and install %s" % library["name"])

    for theme in additional_themes:
        parser.add_option("-%s" % theme["short_arg"], "--%s" % theme["name"].lower(),
                          dest=theme["name"].lower(),
                          action="store_true",
                          help="Build and install %s" % theme["name"])

    parser.add_option("-d", "--project",
                      dest="project",
                      action="store_true",
                      help="Build and deploy project")
    parser.add_option("-a", "--all",
                      dest="all",
                      action="store_true",
                      help="Build and deploy everything without Cappuccino")
    parser.add_option("-E", "--everything",
                      dest="everything",
                      action="store_true",
                      help="Build and deploy everything + Cappuccino")
    parser.add_option("-L", "--libraries",
                      dest="libraries",
                      action="store_true",
                      help="Build all libraries")
    parser.add_option("-w", "--war",
                      dest="generatewar",
                      action="store_true",
                      help="Generate the WAR file for JBOSS deployment")
    parser.add_option("-v", "--verbose",
                      dest="verbose",
                      action="store_true",
                      help="Print commands output")
    parser.add_option("--setversion",
                      dest="buildversion",
                      help="Set the build version")
    parser.add_option("-C", "--clean",
                      dest="clean",
                      action="store_true",
                      help="Clean all libraries and project")
    parser.add_option("--clobber",
                      dest="clobber",
                      action="store_true",
                      help="Clean all libraries, project and cappuccino")
    parser.add_option("--cappinstalldir",
                      default="/usr/local/narwhal",
                      dest="cappuccinoinstalldir",
                      help="Cappuccino install directory")
    parser.add_option("--cappbuilddir",
                      dest="cappuccinobuilddir",
                      help="Cappuccino build directory")
    parser.add_option("--nomanifest",
                      dest="nomanifest",
                      action="store_true",
                      help="disable the HTML5 app.manifest generation")
    parser.add_option("--debug",
                      dest="debug",
                      action="store_true",
                      help="Generate a debug deployment build")

    options, args = parser.parse_args()

    if not options.cappuccinobuilddir and "CAPP_BUILD" in os.environ:
        options.cappuccinobuilddir = os.environ["CAPP_BUILD"]
    if not options.cappuccinobuilddir:
        options.cappuccinobuilddir = "/usr/local/cappuccino"

    options.cappuccinoinstalldir = os.path.expanduser(options.cappuccinoinstalldir)
    options.cappuccinobuilddir = os.path.expanduser(options.cappuccinobuilddir)

    init(install_dir=options.cappuccinoinstalldir, build_dir=options.cappuccinobuilddir)

    if options.clean or options.clobber:
        clean_library(name="NUKit")
        clean_library(name="TNKit")
        clean_library(name="Bambou")

        for library in additional_libraries:
            clean_library(name=library["name"])

        for theme in additional_themes:
            clean_theme(theme["name"])

        clean_project()
        clean_war()

        if options.clobber:
            clean_cappuccino(install_dir=options.cappuccinoinstalldir, build_dir=options.cappuccinobuilddir)

        sys.exit(0)

    if options.nomanifest:
        os.environ["CAPP_NOMANIFEST"] = "1"

    if options.debug:
        os.environ["ARCHITECT_BUILD_DEBUG"] = "1"

    # Required libraries
    if options.everything or options.cappuccino:
        install_cappuccino(install_dir=options.cappuccinoinstalldir,
                           local_distrib="/usr/local/cappuccino-base/current")
    if options.everything or options.all or options.tnkit or options.libraries:
        build_library(name="TNKit")
    if options.everything or options.all or options.bambou or options.libraries:
        build_library(name="Bambou")
    if options.everything or options.all or options.nukit or options.libraries:
        build_library(name="NUKit")

    # Additional User Libraries
    for library in additional_libraries:
        if options.everything or options.all or getattr(options, library["name"].lower()) or options.libraries:
            build_library(name=library["name"])

    # Additional User Themes
    for theme in additional_themes:
        if options.everything or options.all or getattr(options, theme["name"].lower()) or options.libraries:
            build_theme(name=theme["name"])

    if options.everything or options.all or options.project:
        build_project(build_version=options.buildversion)

    if options.everything or options.all or options.generatewar:
        build_war(name=war_name)
