      //****************************************************************
      // PROGRAM NAME:   INVMNT                                        *
      // RELATED FILES:  INVMSTL1 (LF)                                 *
      //                 VNDMSTL1 (LF)                                 *
      //                 INVSCN   (DSPF)                               *
      // DESCRIPTION:    This program is an inventory master           *
      //                 maintenance program using a workstn file. It  *
      //                 allows the user to add, update, and display   *
      //                 inventory items, and to list all items in     *
      //                 item ID order. Quantities are initialized to  *
      //                 zero on add and cannot be changed on update - *
      //                 see INVSELL for the program that adjusts      *
      //                 them. The vendor on an item must already      *
      //                 exist on file (VNDMST); its name is shown,    *
      //                 but not editable, on the display/update       *
      //                 screen.                                       *
      //                 PF3 is used to quit the program.              *
      //****************************************************************

     Finvmstl1  uf a e           k disk
     Fvndmstl1  if   e           k disk
     Finvscn    cf   e             workstn sfile(invlsfl:invRrn)
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
     D   sflClear                      n   overlay(indicators:41)
     D   sflCtlDisp                    n   overlay(indicators:42)
     D   sflDisplay                    n   overlay(indicators:43)
     D   itemExists                    n   overlay(indicators:51)
     D   itemNotFound                  n   overlay(indicators:52)
     D   vendNotFound                  n   overlay(indicators:53)

     D invRrn          s              7p 0

      // Key list definitions:

     C     ItemKey       KLIST
     C                   KFLD                    ITEMID
     C     VendKey       KLIST
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
          elseif itemid <> *blanks;
             if mode = 'UPDATE';
                exsr UpdateSub;
             elseif mode = 'DISPLAY';
                exsr InquirySub;
             endif;
          endif;

          exfmt hdrscn;
          itemExists   = *off;   // turn off error messages
          itemNotFound = *off;
       enddo;

       *inlr = *on;
       //****************************************************************
       //    SUBROUTINE - AddSub                                        *
       //    PURPOSE    - Add a new inventory item; quantities start   *
       //                 at zero, and the vendor must already exist   *
       //****************************************************************
       begsr AddSub;

          // Is this item ID already in file?
          chain ItemKey imlrec1;
          if %found(invmstl1);
             itemExists = *on;
             leavesr;
          endif;

          // Initialize new item data
          descr = *blank;
          vend = 0;
          unit = *blank;
          qoh = 0;
          qoo = 0;
          qpend = 0;
          lorddt = 0;

          // Prompt for the new item's data, re-prompting if the vendor
          // entered doesn't exist
          dow *on;
             exfmt invbld;
             if *in12;
                leavesr;
             endif;
             chain(n) VendKey vndmstl1;
             if not %found(vndmstl1);
                vendNotFound = *on;
                iter;
             endif;
             vendNotFound = *off;
             leave;
          enddo;

          write imlrec1;
       endsr;  // end of subroutine AddSub



       //****************************************************************
       //    SUBROUTINE - UpdateSub                                     *
       //    PURPOSE    - Update description/vendor/unit; quantities   *
       //                 are shown but cannot be changed here         *
       //****************************************************************
       begsr UpdateSub;

          // Lookup item ID
          chain ItemKey imlrec1;
          if not %found(invmstl1);
             itemNotFound = *on;
             leavesr;
          endif;

          // Look up the vendor's name for display
          chain(n) VendKey vndmstl1;

          disableInput = *off;
          dow *on;
             exfmt invinq;
             if prevKey;
                unlock invmstl1;
                leavesr;
             endif;
             chain(n) VendKey vndmstl1;
             if not %found(vndmstl1);
                vendNotFound = *on;
                iter;
             endif;
             vendNotFound = *off;
             leave;
          enddo;

          update imlrec1;
       endsr;  // end of subroutine UpdateSub;
       //****************************************************************
       //    SUBROUTINE - InquirySub                                    *
       //    PURPOSE    - Display an inventory item, including its     *
       //                 vendor's name                                *
       //****************************************************************
       begsr InquirySub;

          // Lookup item ID
          chain(n) ItemKey imlrec1;  // don't lock record
          if not %found(invmstl1);
             itemNotFound = *on;
             leavesr;
          endif;

          // Look up the vendor's name for display
          chain(n) VendKey vndmstl1;

          disableInput = *on;
          exfmt invinq;
       endsr;  // end of subroutine InquirySub;
       //****************************************************************
       //    SUBROUTINE - ListSub                                       *
       //    PURPOSE    - Load and display all items, in item ID       *
       //                 order, into the list subfile                 *
       //****************************************************************
       begsr ListSub;

          // Clear the subfile before reloading it
          sflClear = *on;
          write invlctl;
          sflClear = *off;

          // Load one subfile record per item, in item ID order
          invRrn = 0;
          setll *loval invmstl1;
          read invmstl1;
          dow not %eof(invmstl1);
             invRrn += 1;
             write invlsfl;
             read invmstl1;
          enddo;

          // Display the loaded subfile. SFLDSP must stay off when the
          // subfile has zero records -- turning it on for an empty
          // subfile causes a device error. SFLDSPCTL (the control
          // record's own header) stays on either way.
          sflDisplay = (invRrn > 0);
          sflCtlDisp = *on;
          exfmt invlctl;
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

