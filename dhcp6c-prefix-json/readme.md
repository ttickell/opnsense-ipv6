# A script out of context
This is currently lacking context - it hits one part of my overall goals, which is to have a usable record of what delegations dhcp6c received and what it did with them (if anything).

It merges data from the dhcp6c configuration with data from the log files in a bit of json which includes the prefix delegation ID, any interface assignments, and the size of the interface assignments.

For now, I figured it is most useful to stop there: any consumer of the data must figure out the further subdivision of delegations and put them to actual work.  Keeping a persistent record of those uses is out of scope for this, too.

# To Use
Setup:

1) You must enable additional logging for dhcp6c - in Opnsense, that is in the "Interfaces"->"Settings" page, and should be set to "Info".
2) iscpy must be installed.  Opnsense doesn't include pip, so first you have to install pip - then the version of iscpy on Pypi is broken, so you have to install directly from GitHub.  Notes on both are in the script, itself.

Adjust pathing in the script as required to find your log file, where to save the json, and your dhcp6c configuration.

# Output 
This script generates a file /var/db/dhcp6c-pd.json.
