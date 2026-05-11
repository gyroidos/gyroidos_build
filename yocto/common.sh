#!/usr/bin/env bash
set -euo pipefail

# This file is part of GyroidOS
# Copyright(c) 2013 - 2020 Fraunhofer AISEC
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

LOG_HNAME="$(hostname)"

eprint(){
	[[ -n "${LOGFILE:-}" ]] && echo "    $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "       [1;90m[${LOG_HNAME}] $*[m" >&2
}

elog() {
	[[ -n "${LOGFILE:-}" ]] && echo "LOG: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

edebug() {
	[[ -n "${LOGFILE:-}" ]] && echo "DEBUG: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;90m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

einfo() {
	[[ -n "${LOGFILE:-}" ]] && echo "INFO: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;32m+[m][1;90m[${LOG_HNAME}] $*[m" >&2
}

eattention() {
	[[ -n "${LOGFILE:-}" ]] && echo "ATTENTION: $*" >> "$LOGFILE"
	[[ -n "${QUIET:-}" ]] && return
	echo "    [[1;33m![m][1;33m[${LOG_HNAME}] $*[m" >&2
}

ewarn() {
	[[ -n "${LOGFILE:-}" ]] && echo "WARNING: $*" >> "$LOGFILE"
	echo "    [[1;33m+[m][1;33m[${LOG_HNAME}] $*[m" >&2
}

eerror() {
	[[ -n "${LOGFILE:-}" ]] && echo "ERROR: $*" >> "$LOGFILE"
	echo "   [1;31m* ERROR[m[1;90m[${LOG_HNAME}]: $*[m" >&2
}


die() {
	[[ -n "${LOGFILE:-}" ]] && echo "ERROR, FATAL: $*" >> "$LOGFILE"
	eerror "$*"
	export DIED_ERROR="yes"
	exit 1
}

begin(){
        [[ -n "${QUIET:-}" ]] && return
	echo "[1;36m[[1;32mbegin[1;36m][${LOG_HNAME}] $*[m" >&2
}

ok(){
        [[ -n "${QUIET:-}" ]] && return
	echo "[1;36m[[1;32m   ok[1;36m][${LOG_HNAME}] $*[m" >&2
}

countdown() {
        echo -n "$2" >&2

        local i="$1"
        while [[ $i -gt 0 ]]; do
		echo -n " [1;31m$i[m" >&2
                i=$((i - 1))
                sleep 1
        done
        echo >&2
}
