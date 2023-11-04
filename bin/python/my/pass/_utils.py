_FSTYPE_BLACKLIST = {
    "autofs",
    "bpf",
    "cgroup2",
    "configfs",
    "debugfs",
    "devpts",
    "devtmpfs",
    "efivarfs",
    "fusectl",
    "hugetlbfs",
    "mqueue",
    "proc",
    "pstore",
    "securityfs",
    "sysfs",
    "tmpfs",
    "tracefs",
}


def mountpoints():
    with open("/proc/mounts") as f:
        for line in f:
            _, mountpoint, fstype, _ = line.split(" ", 3)
            if not fstype in _FSTYPE_BLACKLIST:
                yield mountpoint
