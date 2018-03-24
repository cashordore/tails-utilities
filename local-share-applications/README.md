# README for applications
Install all files into ~amnesia/.local/share/applications/

# SETUP
make sure the ~amnesia/.local is part of your persistence configuration

## Duplicate 
> `Duplicate.desktop` - desktop shortcut that invokes the duplicate.bash script.
>
>`duplicate.bash` - bash (shell) script that duplicates one USB to another USB. 
>

## Backup
>'Backup-Persistent-Data.desktop' - desktop shortcut that invokes the backup.bash shell script.
>
>`backup.bash` - runs the backup. Encrypted backup files saved to ~/Persistent/.
>

## Restore
>`Restore-Persistent-Data.desktop` - desktop shortcut that invokes the restore.bash shell script.
>
>`restore.bash` - runs the restore. Decryptes and restores backup file; looks for file in ~/Persistent/.
>

