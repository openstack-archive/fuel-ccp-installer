#!/bin/bash -eux

# Zero out the free space to save space in the final image
nice -n 19 ionice -c2 -n7 dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY

# Make sure we wait until all the data is written to disk, otherwise
# Packer might quite too early before the large files are deleted
sync
