;;;
;;; Code supporting FAT12 and FAT32 directories
;;;

;
; Open a directory and seek the first entry.
;
; NOTE: at the moment, this only supports reading the root directory of the SDC.
;       Support for subdirectories and other block devices will come later.
;
; Inputs:
;   DOS_FD_PTR = pointer to the file descriptor
;
; Outputs:
;   DOS_FD_PTR = pointer to the file descriptor
;   DOS_DIR_PTR = pointer to the current directory entry
;   DOS_DIR_BLOCK_ID = the ID of the current directory block on the disk
;   DOS_DIR_TYPE = the type of the directory (0 = cluster based, $80 = sector based [FAT12 root directory])
;   DOS_STATUS = status code for any DOS-related errors (0 = fine)
;   BIOS_STATUS = status code for any BIOS-related errors (0 = fine)
;   C = set if success, clear on error
;
DOS_DIROPEN     .proc
                PHX
                PHY
                PHD
                PHB
                PHP

                setdbr `DOS_HIGH_VARIABLES
                setdp SDOS_VARIABLES

                TRACE "DOS_DIROPEN"

                setas
                LDY #FILEDESC.DEV           ; Set the device from the file descriptor
                LDA [DOS_FD_PTR],Y
                STA BIOS_DEV

                ; TODO: parse the path

                setaxl
                JSL DOS_MOUNT               ; Make sure we've mounted the SDC.
                BCS get_root_dir            ; If successful: get the root directory
                BRL IF_PASSFAILURE          ; Otherwise: pass the error up the chain

get_root_dir    setaxl

                ; TODO: get the block from the path

                LDA ROOT_DIR_FIRST_CLUSTER  ; Set the cluster (or sector for FAT12)
                STA DOS_DIR_BLOCK_ID        ; to that of the root directory's start
                LDA ROOT_DIR_FIRST_CLUSTER+2
                STA DOS_DIR_BLOCK_ID+2

                LDA #<>DOS_DIR_CLUSTER      ; Point to the directory cluster buffer for loading
                STA DOS_BUFF_PTR
                STA DOS_DIR_PTR
                LDA #`DOS_DIR_CLUSTER
                STA DOS_BUFF_PTR+2
                STA DOS_DIR_PTR+2

                setas
                LDA FILE_SYSTEM             ; Check the file system
                CMP #PART_TYPE_FAT12        ; Is it FAT12?
                BNE fetch_fat32             ; No: handle processing the diretory as FAT32

                ; Otherwise: treat as FAT12 and load from disk

fetch_fat12     setal
                LDA DOS_DIR_PTR             ; Set the BIOS buffer pointer
                STA BIOS_BUFF_PTR
                LDA DOS_DIR_PTR+2
                STA BIOS_BUFF_PTR+2

                LDA DOS_DIR_BLOCK_ID        ; Set the LBA of the sector
                STA BIOS_LBA
                LDA DOS_DIR_BLOCK_ID+2
                STA BIOS_LBA+2

                JSL GETBLOCK                ; Get the sector from the FAT12 device
                BCS do_success              ; If sucessful, set the directory cursor
                BRL IF_PASSFAILURE          ; Otherwise: pass up the failure

fetch_fat32     setal
                LDA DOS_DIR_BLOCK_ID
                STA DOS_CLUS_ID
                LDA DOS_DIR_BLOCK_ID+2
                STA DOS_CLUS_ID+2

                JSL DOS_GETCLUSTER          ; Try to read the first cluster
                BCS do_success              ; If successful: set the directory cursor
                BRL IF_PASSFAILURE          ; Otherwise: pass up the failure

do_success      BRL IF_SUCCESS
                .pend

;
; Set the directory entry pointer to the beginning of the currently loaded sector
;
; Outputs:
;   DOS_DIR_PTR = points to the first directory entry
;
DOS_DIRFIRST    .proc
                PHD
                PHP

                setdp SDOS_VARIABLES

                setal
                LDA #<>DOS_DIR_CLUSTER
                STA DOS_DIR_PTR
                LDA #`DOS_DIR_CLUSTER
                STA DOS_DIR_PTR+2

                PLP
                PLD
                RTL
                .pend

;
; Get the next directory entry, reading the next cluster, if necessary.
;
; Inputs:
;   DOS_FD_PTR = pointer to the file descriptor
;   DOS_DIR_PTR = pointer to the current directory entry.
;   DOS_DIR_BLOCK_ID = the ID of the current directory block on the disk
;   DOS_DIR_TYPE = the type of the directory (0 = cluster based, $80 = sector based [FAT12 root directory])
;
; Outputs:
;   DOS_FD_PTR = pointer to the file descriptor
;   DOS_DIR_PTR = pointer to the current directory entry
;   DOS_DIR_BLOCK_ID = the ID of the current directory block on the disk
;   DOS_DIR_TYPE = the type of the directory (0 = cluster based, $80 = sector based [FAT12 root directory])
;   DOS_STATUS = status code for any DOS-related errors (0 = fine)
;   BIOS_STATUS = status code for any BIOS-related errors (0 = fine)
;   C = set if success, clear on error
;
DOS_DIRNEXT     .proc
                PHX
                PHY
                PHD
                PHB
                PHP

                setdbr `DOS_HIGH_VARIABLES
                setdp SDOS_VARIABLES

                TRACE "DOS_DIRNEXT"

                setal
                CLC                         ; Advance the directory entry pointer to the next entry
                LDA DOS_DIR_PTR
                ADC #DOS_DIR_ENTRY_SIZE
                STA DOS_DIR_PTR
                LDA DOS_DIR_PTR+2
                ADC #0
                STA DOS_DIR_PTR+2

                SEC                         ; Check to see if we've reached the end of the sector buffer
                LDA #<>DOS_DIR_CLUSTER_END
                SBC DOS_DIR_PTR
                LDA #`DOS_DIR_CLUSTER_END
                SBC DOS_DIR_PTR+2
                BMI get_next_block
                BRL IF_SUCCESS

                ; TODO: next decision only applies to the root directory!

get_next_block  setas
                LDA DOS_DIR_TYPE            ; Check the type of the directory
                BEQ next_cluster            ; If 0, it's cluster based (FAT32, or FAT12 non-root)

                ; FAT12, root directory case

next_sector     setal                       ; Yes: treat as the root directory of the floppy disk
                LDA DOS_DIR_BLOCK_ID
                INC A
                STA DOS_DIR_BLOCK_ID        ; Increment the sector number (FAT12 root directory is sector based)
                CMP #10                     ; See if we're at the end (TODO: calculate this)
                BNE read_sector
                
                setas                       ; End of the line... return a failure
                LDA #0
                BRL IF_FAILURE

read_sector     setal                       ; Load the sector from the floppy disk
                LDA DOS_DIR_BLOCK_ID        ; Set the LBA to the sector #
                STA BIOS_LBA
                LDA DOS_DIR_BLOCK_ID+2
                STA BIOS_LBA+2

                LDA #<>DOS_DIR_CLUSTER      ; Set the pointers to the buffer
                STA BIOS_BUFF_PTR
                STA DOS_DIR_PTR
                LDA #`DOS_DIR_CLUSTER
                STA BIOS_BUFF_PTR+2
                STA DOS_DIR_PTR+2

                JSL GETBLOCK                ; Attempt to read the sector from the FAT12 device
                BCS do_success              ; If successful: set the directory cursor
                BRL IF_PASSFAILURE          ; Otherwise: pass up the failure

                ; FAT32, or FAT-12 non-root case

next_cluster    setal
                LDA DOS_DIR_BLOCK_ID        ; Get the current block (cluster) ID
                STA DOS_CLUS_ID
                LDA DOS_DIR_BLOCK_ID+2
                STA DOS_CLUS_ID+2

                LDA #<>DOS_DIR_CLUSTER
                STA DOS_BUFF_PTR
                STA DOS_DIR_PTR
                LDA #`DOS_DIR_CLUSTER
                STA DOS_BUFF_PTR+2
                STA DOS_DIR_PTR+2

                JSL NEXTCLUSTER             ; Try to find the next cluster
                BCS set_next
                BRL IF_PASSFAILURE          ; If error: pass it up the chain

set_next        LDA DOS_CLUS_ID             ; Save the cluster as the current directory cluster
                STA DOS_DIR_BLOCK_ID
                LDA DOS_CLUS_ID+2
                STA DOS_DIR_BLOCK_ID+2

                JSL DOS_GETCLUSTER          ; Try to read the first cluster
                BCS do_success              ; If successful: set the directory cursor
                BRL IF_PASSFAILURE          ; Otherwise: pass up the failure

do_success      BRL IF_SUCCESS
                .pend

;
; Find a free entry in the directory
;
; Inputs:
;   ??? = Something to set the correct directory
;
; Outputs:
;   DOS_DIR_BLOCK_ID = cluster containing the directory entry
;   DOS_DIR_CLUSTER = the data in the directory cluster
;   DOS_DIR_PTR = points to the first directory entry in DOS_DIR_CLUSTER
;   DOS_STATUS = the status code for the operation
;   C = set if there is a next cluster, clear if there isn't
;
DOS_DIRFINDFREE .proc
                PHX
                PHY
                PHD
                PHB
                PHP

                setdbr `DOS_HIGH_VARIABLES
                setdp SDOS_VARIABLES

                TRACE "DOS_DIRFINDFREE"

                ; Load the first cluster of the directory
                JSL IF_DIROPEN
                BCS start_walk

                LDA #DOS_ERR_NODIR          ; Return that we could not read the directory
                BRL ret_failure

                ; Walk through each entry in the cluster

start_walk      LDY #0                      ; We check the first character of the entry

chk_entry       setas
                LDA [DOS_DIR_PTR],Y         ; Get the first byte of the directory entry
                BEQ ret_success             ; If 0: we have a blank... return it

                CMP #DOS_DIR_ENT_UNUSED     ; Is it an unused (deleted) entry?
                BEQ ret_success             ; Yes: return it

                JSL IF_DIRNEXT              ; Go to the next directory entry
                BCS start_walk              ; If we got one, start walking it

                BRK                         ; For the moment, just fail
                NOP                         ; TODO: add a new cluster to the end of the directory

                ; If there isn't one, create a blank cluster
                ; ... Append the cluster to the directory
                ; ... Return the first entry

ret_failure     BRL IF_FAILURE

ret_success     BRL IF_SUCCESS
                .pend

;
; Write the current directory block back to the disk
;
; Inputs:
;   DOS_DIR_PTR = pointer to the current directory entry.
;   DOS_DIR_BLOCK_ID = the ID of the current directory block on the disk
;   DOS_DIR_TYPE = the type of the directory (0 = cluster based, $80 = sector based [FAT12 root directory])
;
; Outputs:
;   DOS_STATUS = status code for any DOS-related errors (0 = fine)
;   BIOS_STATUS = status code for any BIOS-related errors (0 = fine)
;   C = set if success, clear on error
;
DOS_DIRWRITE    .proc
                PHX
                PHY
                PHD
                PHB
                PHP

                setdbr `DOS_HIGH_VARIABLES
                setdp SDOS_VARIABLES

                TRACE "DOS_DIRWRITE"

                setas
                LDA DOS_DIR_TYPE            ; Check the type of the directory
                BEQ write_cluster           ; If 0, it's cluster based (FAT32, or FAT12 non-root)

                ; FAT12 root directory, write as a sector

write_sector    setal
                LDA DOS_DIR_BLOCK_ID        ; Set the BIOS_LBA to the LBA of the sector
                STA BIOS_LBA
                LDA DOS_DIR_BLOCK_ID+2
                STA BIOS_LBA+2

                LDA #<>DOS_DIR_CLUSTER      ; Set the pointer to the directory buffer
                STA BIOS_BUFF_PTR
                LDA #`DOS_DIR_CLUSTER
                STA BIOS_BUFF_PTR+2

                JSL PUTBLOCK                ; Try to write the sector to disk
                BCS ret_success

ret_failure     BRL IF_FAILURE

                ; FAT32 or FAT12 non-root directory

write_cluster   TRACE "write_cluster"
                setal
                LDA DOS_DIR_BLOCK_ID        ; Set the DOS_CLUS_ID to the ID of the cluster
                STA DOS_CLUS_ID
                LDA DOS_DIR_BLOCK_ID+2
                STA DOS_CLUS_ID+2

                LDA #<>DOS_DIR_CLUSTER      ; Set the pointer to the directory buffer
                STA DOS_BUFF_PTR
                LDA #`DOS_DIR_CLUSTER
                STA DOS_BUFF_PTR+2

                JSL DOS_PUTCLUSTER          ; Try to write the cluster to disk
                BCC ret_failure

ret_success     BRL IF_SUCCESS
                .pend

