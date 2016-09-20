#!/bin/bash
#
# This file is part of trust|me
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
# Fraunhofer AISEC <trustme@aisec.fraunhofer.de>
#

if [ $# -ne 5 -o ! -d $3 -o ! -d $4  -o ! -d $5 ]; then
    echo "Usage: $0 <a0|a1|a2> <feature> <overlay-device-dir> <out-trustme-device-dir> <input dir containing system/>"
else
    container=$1
    feature=$2
    list=$3/remove-system-files-from-aX-$feature
    root=$4
    input=$5

    if [ -r $list ]; then
	mkdir -p $root/feature_${feature}_${container}/system
	cat $list | while read line
	do 
	    # Comment line?
	    if  [[ $line =~ ^# ]]; then
		echo $line
	    else
		file=${input}/system/${line}
		if [ -r "$file" ]; then
		    #rm -r -v $file
                    mkdir -p $root/feature_${feature}_${container}/system/$(dirname $line)
                    mv $file $root/feature_${feature}_${container}/system/$line
                    echo "$line -> feature_${feature}_${container}/system/$line"
		fi
	    fi
	done
    else
	echo "No system files to be removed from $container"
    fi
fi
