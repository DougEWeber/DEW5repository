      //****************************************************************
      // PROGRAM NAME:   ORDVIEW                                       *
      // RELATED FILES:  ORDHDRL1 (LF)                                 *
      //                 ORDDTLL2 (LF)                                 *
      //                 INVMSTL1 (LF)                                 *
      //                 ORDVSCN  (DSPF)                               *
      // DESCRIPTION:    Read-only order viewer: prompts for an order  *
      //                 ID and shows its header (customer, date,      *
      //                 state) and every line on it (item, its        *
      //                 description, quantity, price), in a subfile.  *
      //                 PF3 is used to quit the program.              *
      //****************************************************************

     Fordhdrl1  if   e           k disk
     Forddtll2  if   e           k disk
     Finvmstl1  if   e           k disk
     Fordvscn   cf   e             workstn sfile(viewsfl:viewRrn)
     F                                     indds(indicators)

      // Field definitions:

     D indicators      ds
     D   exitKey                       n   overlay(indicators:3)
     D   sflClear                      n   overlay(indicators:41)
     D   sflCtlDisp                    n   overlay(indicators:42)
     D   sflDisplay                    n   overlay(indicators:43)
     D   ordNotFound                   n   overlay(indicators:52)

     D viewRrn         s              7p 0
     D reqOrdId        s              7p 0
     D stateds         s             12a
     D itemdesc        s             25a

      // Key list definitions:

     C     OrdKey        KLIST
     C                   KFLD                    ORDERID
      //*****************************************************************
      //       MAINLINE                                                 *
      //*****************************************************************

      /free

       exfmt hdrscn;
       dow not exitKey;
          chain(n) OrdKey ohlrec1;
          if not %found(ordhdrl1);
             ordNotFound = *on;
          else;
             ordNotFound = *off;
             reqOrdId = orderid;
             exsr SetStateDs;
             exsr LoadAndShowLines;
          endif;
          exfmt hdrscn;
       enddo;

       *inlr = *on;
       //****************************************************************
       //    SUBROUTINE - SetStateDs                                    *
       //    PURPOSE    - Translate the 1-character state code into a  *
       //                 readable description for display            *
       //****************************************************************
       begsr SetStateDs;
          select;
          when ordstate = 'E';
             stateds = 'ENTERING';
          when ordstate = 'P';
             stateds = 'IN PROCESS';
          when ordstate = 'S';
             stateds = 'SHIPPED';
          when ordstate = 'C';
             stateds = 'COMPLETED';
          when ordstate = 'X';
             stateds = 'CANCELLED';
          when ordstate = 'D';
             stateds = 'IN DISPUTE';
          other;
             stateds = 'UNKNOWN';
          endsl;
       endsr;  // end of subroutine SetStateDs
       //****************************************************************
       //    SUBROUTINE - LoadAndShowLines                              *
       //    PURPOSE    - Load every line of the requested order (in   *
       //                 line ID order) into the subfile, looking up  *
       //                 each item's description along the way, then *
       //                 display it                                  *
       //****************************************************************
       begsr LoadAndShowLines;
          sflClear = *on;
          write viewctl;
          sflClear = *off;

          viewRrn = 0;
          setll OrdKey orddtll2;
          read(n) orddtll2;
          dow not %eof(orddtll2) and orderid = reqOrdId;
             chain(n) itemid invmstl1;
             itemdesc = %subst(descr:1:25);
             viewRrn += 1;
             write viewsfl;
             read(n) orddtll2;
          enddo;

          // Restore the header's ORDERID -- the loop above overwrote the
          // shared global with each line's own ORDERID as it read them.
          orderid = reqOrdId;

          sflDisplay = (viewRrn > 0);
          sflCtlDisp = *on;
          exfmt viewctl;
          sflDisplay = *off;
          sflCtlDisp = *off;
       endsr;  // end of subroutine LoadAndShowLines

      /end-free

