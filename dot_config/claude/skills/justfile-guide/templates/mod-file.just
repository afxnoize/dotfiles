# Mod template (file type). Copy to ./<name>.just and declare `mod <name>` in the root justfile.
# Recipes run in the same directory as the root justfile.

import "_common.just"

# systemctl --user status my-backup.timer
[group('observe')]
status:
    systemctl --user status my-backup.timer

# journalctl --user -u my-backup.service -n {{count}}
[group('observe')]
logs count="50":
    journalctl --user -u my-backup.service -n {{ count }}

# systemctl --user disable --now my-backup.timer
[confirm("This stops and disables the backup timer. Continue?")]
[group('lifecycle')]
stop:
    systemctl --user disable --now my-backup.timer
