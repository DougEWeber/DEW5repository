      //****************************************************************
      // PROGRAM NAME:   VNDMNT                                        *
      // RELATED FILES:  VNDMSTL1 (LF)                                 *
      //                 VNDMSTL2 (LF)                                 *
      //                 VNDSCN   (DSPF)                               *
      // DESCRIPTION:    This program is a vendor master maintenance   *
      //                 program using a workstn file. It allows the   *
      //                 user to add (with a system-generated vendor   *
      //                 number), update, and display vendor records,  *
      //                 and to list all vendors in vendor name order. *
      //                 PF3 is used to quit the program.              *
      //****************************************************************

     Fvndmstl1  uf a e           k disk
     Fvndmstl2  if   e           k disk
     Fvndscn    cf   e             workstn sfile(vndlsfl:sflRrn)
     F                                     indds(indicators)

      // Field definitions:

     D indicators      ds
     D   exitKey                       n   overlay(indicators:3)
     D   disableInput                  n   overlay(indicators:4)
     D   addKey                        n   overlay(indicators:5)
     D   updateKey                     n   overlay(indicators:6)
     D   displayKey                    n   overlay(indicators:8)
     D   listKey                       n   overlay(indicators:9)
     D   prevKey                       n   overlay(indicators:12)
     D   vendNotFound                  n   overlay(indicators:52)
     D   sflClear                      n   overlay(indicators:41)
     D   sflCtlDisp                    n   overlay(indicators:42)
     D   sflDisplay                    n   overlay(indicators:43)

     D sflRrn          s              5p 0

      // Key list definitions:

     C     VNDKEY        KLIST
     C                   KFLD                    VEND
      //*****************************************************************
      //       MAINLINE                                                 *
      //*****************************************************************

      /free

       mode = 'DISPLAY';
       exfmt hdrscn;

       // Loop until exit key is pressed
       dow not exitKey;
          exsr SetMaintenanceMode;

          if mode = 'ADD';
             exsr AddSub;
          elseif mode = 'LIST';
             exsr ListSub;
          elseif vend <> 0;
             if mode = 'UPDATE';
                exsr UpdateSub;
             elseif mode = 'DISPLAY';
                exsr InquirySub;
             endif;
          endif;

          exfmt hdrscn;
          vendNotFound = *off;   // turn off error messages
       enddo;

       *inlr = *on;
       //****************************************************************
       //    SUBROUTINE - AddSub                                        *
       //    PURPOSE    - Generate the next vendor number and add a new *
       //                 vendor to the file                           *
       //****************************************************************
       begsr AddSub;

          // Determine the next available vendor number: position to
          // the last (highest-keyed) record and add 1. An empty file
          // starts numbering at 1.
          setll *hival vndmstl1;
          readp vndmstl1;
          if %eof(vndmstl1);
             vend = 1;
          else;
             vend = vend + 1;
          endif;

          // Initialize new vendor data
          name = *blank;
          addr = *blank;
          phone = *blank;

          // Prompt for the new vendor's data
          exfmt vndbld;

          // If OK, add the vendor to the vendor file
          if not *in12;
             write vmlrec1;
          endif;
       endsr;  // end of subroutine AddSub



       //****************************************************************
       //    SUBROUTINE - UpdateSub                                     *
       //    PURPOSE    - Update vendor master record                   *
       //****************************************************************
       begsr UpdateSub;

          // Lookup vendor number
          chain vndkey vmlrec1;
          if not %found(vndmstl1);
             // Vendor is not found in file
             vendNotFound = *on;
             leavesr;
          endif;

          // Display information for this vendor
          disableInput = *off;
          exfmt vndinq;
          if not prevKey;
             // Update information in file
             update vmlrec1;
          else;
             // If we don't want to update, at least unlock
             // the record.
             unlock vndmstl1;
          endif;
       endsr;  // end of subroutine UpdateSub;
       //****************************************************************
       //    SUBROUTINE - InquirySub                                    *
       //    PURPOSE    - Display vendor master record                  *
       //****************************************************************
       begsr InquirySub;

          // Lookup vendor number
          chain(n) vndkey vmlrec1;  // don't lock record
          if not %found(vndmstl1);
             // Vendor is not found in file
             vendNotFound = *on;
             leavesr;
          endif;

          // Display information for this vendor
          disableInput = *on;
          exfmt vndinq;
       endsr;  // end of subroutine InquirySub;
       //****************************************************************
       //    SUBROUTINE - ListSub                                       *
       //    PURPOSE    - Load and display all vendors, in vendor name  *
       //                 order, into the list subfile                 *
       //****************************************************************
       begsr ListSub;

          // Clear the subfile before reloading it
          sflClear = *on;
          write vndlctl;
          sflClear = *off;

          // Load one subfile record per vendor, in name order
          sflRrn = 0;
          setll *loval vndmstl2;
          read vndmstl2;
          dow not %eof(vndmstl2);
             sflRrn += 1;
             write vndlsfl;
             read vndmstl2;
          enddo;

          // Display the loaded subfile. SFLDSP must stay off when
          // the subfile has zero records -- turning it on for an
          // empty subfile causes a device error. SFLDSPCTL (the
          // control record's own header) stays on either way.
          sflDisplay = (sflRrn > 0);
          sflCtlDisp = *on;
          exfmt vndlctl;
          sflDisplay = *off;
          sflCtlDisp = *off;
       endsr;  // end of subroutine ListSub
       //****************************************************************
       //    SUBROUTINE - SetMaintenanceMode                            *
       //    PURPOSE    - Set maintenance mode                          *
       //****************************************************************
       begsr SetMaintenanceMode;
          if addKey;
             mode = 'ADD';
          elseif updateKey;
             mode = 'UPDATE';
          elseif displayKey;
             mode = 'DISPLAY';
          elseif listKey;
             mode = 'LIST';
          endif;
       endsr;  // end of subroutine SetMaintenanceMode

      /end-free

