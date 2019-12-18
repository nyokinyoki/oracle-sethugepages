# oracle-sethugepages
Enable HugePages based on [Oracle's guidelines](https://docs.oracle.com/database/121/UNXAR/appi_vlm.htm#UNXAR391).

- if it runs successfully, do `grep Huge /proc/meminfo` to see if everything is in order
- reboot at least one instance, so you see if the settings persist

This script contains a snippet made by Oracle.
