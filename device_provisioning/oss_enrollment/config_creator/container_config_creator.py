# -*- coding: utf-8 -*-
#
# This file is part of GyroidOS
# Copyright(c) 2013 - 2017 Fraunhofer AISEC
# Fraunhofer-Gesellschaft zur Förderung der angewandten Forschung e.V.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms and conditions of the GNU General Public License,
# version 2 (GPL 2), as published by the Free Software Foundation.
#
# This program is distributed in the hope it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GPL 2 license for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <http://www.gnu.org/licenses/>
#
# The full GNU General Public License is included in this distribution in
# the file called "COPYING".
#
# Contact Information:
# Fraunhofer AISEC <gyroidos@aisec.fraunhofer.de>
#

import argparse
import hashlib
import os
import sys
from time import strftime
from google.protobuf import text_format

import container_pb2


parser = argparse.ArgumentParser(description='Generate a container config file '
                                             'using a basic config.')
parser.add_argument('-c', '--path_to_new_config', dest='path_to_new_config',
                   default="new_container_config.conf",
                   help='Path where the generated config is saved')
parser.add_argument('-n', '--name', dest='name', default="a0",
                   help='Name of the container')
parser.add_argument('-go', '--guest_os', dest='guest_os',
                   help='Name of the guest os')
parser.add_argument('-v', '--guestos_version', dest='guestos_version',
                   help='Version of the guest os')
parser.add_argument('-co', '--color', dest='color',
                   help='color of a container')
parser.add_argument('-s', '--def_size', dest='def_size', default="1024",
                   help='Default size of userdata partition of a container')


args = parser.parse_args()
container = container_pb2.ContainerConfig()

container.name = args.name
container.color = int(args.color, 0)
container.guest_os = args.guest_os
container.guestos_version = int(args.guestos_version)

container.image_sizes.add(image_name = "data", image_size = int(args.def_size))

try:
    with open(args.path_to_new_config, "w") as f:
        f.write(text_format.MessageToString(container))
except IOError:
    print(sys.argv[1] + ": Could not open new config file for writing. Aborting.")
    sys.exit()
