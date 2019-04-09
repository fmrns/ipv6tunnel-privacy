#!/bin/sh
#
# Copyright (c) 2019 Abacus Technologies, Inc.
# Copyright (c) 2019 Fumiyuki Shimizu
# MIT License: https://opensource.org/licenses/MIT
#
# req: net-mgmt/ipv6calc ftp://ftp.bieringer.de/pub/linux/IPv6/ipv6calc/

umask 0077
PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/local/sbin:/usr/local/bin

rc=1

IFN='gif0'
PREFIXLEN='64'
PREFIX='2001:470:xx:xxxx:'

# storage of ipv6 addresses
IFFILE='/var/db/gif6'
[ -e "$IFFILE" ] || touch "$IFFILE"

BN=$(basename "$0")
TMPD=$(mktemp -d /tmp/.abacus."$BN".XXXXXXXXXXX)
[ -n "$TMPD" -a -d "$TMPD" ] || { echo 'Cannot create temporary directory.'; exit $rc; }
cleanup1 () {
  rm -rf "$TMPD"
  exit $rc
}
trap 'cleanup1' EXIT TERM

mktempf () {
  local tf
  tf=$(mktemp "$TMPD/.abacus.$BN.1.XXXXXXXXXX")
  [ -n "$tf" -a -w "$tf" ] || { echo 'Cannot create temporary file.'; exit $rc; }
  echo -n "$tf"
}

TMP1=$(mktempf)
TMP2=$(mktempf)
while true; do
  ip6=$(/usr/local/bin/openssl rand -hex 8 | sed -E -e 's/([[:xdigit:]]{4,4})([[:xdigit:]]{4,4})([[:xdigit:]]{4,4})([[:xdigit:]]{4,4})/'$PREFIX'\1:\2:\3:\4/')
  ip6=$(/usr/local/bin/ipv6calc --addr_to_compressed "$ip6")
  ifconfig "$IFN" | sed -n -E -e 's/^[[:space:]]+inet6[[:space:]]+([^[:space:]]+)[[:space:]].*$/\1/p' >"$TMP2"
  ndp -na | cut -w -f 1 | sed -E -e 's/%.*$//' >>"$TMP2"
  sort -f "$TMP2" | uniq -i >"$TMP1"
  echo "$ip6" >>"$TMP1"
  d=$(sort -f "$TMP1" | uniq -id)
  [ -z "$d" ] && break
done

ifconfig "$IFN" inet6 "$ip6" prefixlen "$PREFIXLEN" alias prefer_source
tail -r "$IFFILE" >"$TMP1"
head -n 5 "$TMP1" | while read -r ip; do
  ifconfig "$IFN" inet6 "$ip" deprecated
done
tail -n +6 "$TMP1" | while read -r ip; do
  ifconfig "$IFN" inet6 "$ip" -alias
done
tail -n 5 "$IFFILE" >"$TMP1"
echo "$ip6"        >>"$TMP1"
cat "$TMP1" >"$IFFILE"

rm -f "$TMP1" "$TMP2"

# end of file
