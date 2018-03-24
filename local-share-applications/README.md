# Install and Setup
1. make sure all `\*.bash` files are executable:
    1. `chmod 755 \*.bash`
1. copy files to `~amnesia/.local/share/applications` as follows:
    1.  `cp *.desktop ~amnesia/.local/share/applications`
    1.  `cp *.bash ~amnesia/.local/share/applications`
1. confirm that the following line is in `/live/persistence/TailsData_unlocked/persistence.conf`
    1. `/home/amnesia/.local	source=local`
    1. *note: you must reboot after modifying the `persistence.conf` file*

# Included Utilities

## Duplicate 
> `Duplicate.desktop` - desktop shortcut that invokes the `duplicate.bash` script, can only be run by root.
>
> `duplicate.bash` - bash (shell) script that duplicates one USB to another USB. 
>

## Backup
> 'Backup-Persistent-Data.desktop' - desktop shortcut that invokes the `backup.bash` shell script, can only be run by root.
>
> `backup.bash` - runs the backup. Encrypted backup files saved to ~/Persistent/.
>

## Restore
> `Restore-Persistent-Data.desktop` - desktop shortcut that invokes the `restore.bash` shell script, can only be run by root.
>
> `restore.bash` - runs the restore. Decryptes and restores backup file; looks for file in ~/Persistent/.
>

