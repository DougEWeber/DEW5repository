      //****************************************************************
      // PROGRAM NAME:   ORDSTAT                                       *
      // RELATED FILES:  ORDHDRL1 (LF)                                 *
      //                 ORDDTLL2 (LF)                                 *
      //                 INVMSTL1 (LF)                                 *
      //                 ORDSSCN  (DSPF)                               *
      // DESCRIPTION:    Order state maintenance. Prompts for an order *
      //                 that has already left the entering state,     *
      //                 shows it (header + lines), and lets the user  *
      //                 change its state. Entering the cancelled      *
      //                 state requires confirmation and undoes each   *
      //                 line's InvSell effect (restores quantity on   *
      //                 hand -- the order was already accepted, so    *
      //                 its quantity is no longer pending). Once an   *
      //                 order is cancelled, its state can no longer   *
      //                 be changed.                                  *
      //                 PF3 is used to quit the program.              *
      //****************************************************************

     Fordhdrl1  uf a e           k disk
     Forddtll2  if   e           k disk
     Finvmstl1  uf a e           k disk
     Fordsscn   cf   e             workstn sfile(statsfl:viewRrn)
     F                                     indds(indicators)

      // Field definitions:

     D indicators      ds
     D   exitKey                       n   overlay(indicators:3)
     D   prevKey                       n   overlay(indicators:12)
     D   sflClear                      n   overlay(indicators:41)
     D   sflCtlDisp                    n   overlay(indicators:42)
     D   sflDisplay                    n   overlay(indicators:43)
     D   ordNotFound                   n   overlay(indicators:52)
     D   stillEnter                    n   overlay(indicators:53)
     D   invalidState                  n   overlay(indicators:54)
     D   cancLocked                    n   overlay(indicators:55)
     D   stateProtect                  n   overlay(indicators:56)
     D   normalPhase                   n   overlay(indicators:72)
     D   cancelPhase                   n   overlay(indicators:73)

     D viewRrn         s              7p 0
     D reqOrdId        s              7p 0
     D wOrderId        s              7p 0
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
             stillEnter = *off;
          elseif ordstate = 'E';
             ordNotFound = *off;
             stillEnter = *on;
          else;
             ordNotFound = *off;
             stillEnter = *off;
             reqOrdId = orderid;
             exsr StateChangeLoop;
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
       //    SUBROUTINE - LoadStatusView                                *
       //    PURPOSE    - Clear and reload the line subfile for the    *
       //                 requested order and refresh its state text   *
       //****************************************************************
       begsr LoadStatusView;
          exsr SetStateDs;

          sflClear = *on;
          write statctl;
          sflClear = *off;

          viewRrn = 0;
          setll orderid orddtll2;
          read(n) orddtll2;
          dow not %eof(orddtll2) and orderid = wOrderId;
             chain(n) itemid invmstl1;
             itemdesc = %subst(descr:1:25);
             viewRrn += 1;
             write statsfl;
             read(n) orddtll2;
          enddo;

          // Restore ORDERID -- the loop above overwrote this shared global
          // with each detail line's own ORDERID as it read them.
          orderid = wOrderId;

          sflDisplay = (viewRrn > 0);
          sflCtlDisp = *on;
       endsr;  // end of subroutine LoadStatusView

       //****************************************************************
       //    SUBROUTINE - StateChangeLoop                               *
       //    PURPOSE    - Let the user pick a new state for the order. *
       //                 Moving to cancelled requires confirmation on *
       //                 the same screen; an already-cancelled order  *
       //                 shows the state field locked/protected.     *
       //****************************************************************
       begsr StateChangeLoop;
          wOrderId = reqOrdId;
          cancelPhase = *off;
          invalidState = *off;
          cancLocked = (ordstate = 'X');
          stateProtect = cancLocked;
          normalPhase = not cancLocked;
          newstate = *blank;
          exsr LoadStatusView;

          dow *on;
             exfmt statctl;

             if prevKey and cancelPhase;
                // Step back from the cancel confirmation to normal entry
                cancelPhase = *off;
                stateProtect = *off;
                normalPhase = *on;
                invalidState = *off;
                exsr LoadStatusView;
                iter;
             endif;

             if prevKey;
                leave;  // back to the order ID prompt
             endif;

             if cancLocked;
                iter;  // field is protected; nothing to process
             endif;

             if cancelPhase;
                // Any Enter here confirms the cancellation
                exsr ApplyCancel;
                leave;
             endif;

             select;
             when newstate = 'E' or newstate = 'P' or newstate = 'S'
                          or newstate = 'C' or newstate = 'D';
                invalidState = *off;
                exsr ApplyStateChange;
                leave;
             when newstate = 'X';
                invalidState = *off;
                normalPhase = *off;
                cancelPhase = *on;
                stateProtect = *on;
                exsr LoadStatusView;
             other;
                invalidState = *on;
             endsl;
          enddo;
       endsr;  // end of subroutine StateChangeLoop

       //****************************************************************
       //    SUBROUTINE - ApplyStateChange                              *
       //    PURPOSE    - Set the order to the requested (non-cancel)  *
       //                 state                                        *
       //****************************************************************
       begsr ApplyStateChange;
          chain wOrderId ohlrec1;
          ordstate = newstate;
          update ohlrec1;
       endsr;  // end of subroutine ApplyStateChange

       //****************************************************************
       //    SUBROUTINE - ApplyCancel                                   *
       //    PURPOSE    - Undo InvSell's effect for every line (the      *
       //                 order was already accepted, so its quantity   *
       //                 is in QOH, not QPEND) and set the order to    *
       //                 the cancelled state                          *
       //****************************************************************
       begsr ApplyCancel;
          setll orderid orddtll2;
          read(n) orddtll2;
          dow not %eof(orddtll2) and orderid = wOrderId;
             chain itemid invmstl1;
             qoh = qoh + qty;
             update imlrec1;
             read(n) orddtll2;
          enddo;

          chain wOrderId ohlrec1;
          ordstate = 'X';
          update ohlrec1;
       endsr;  // end of subroutine ApplyCancel

      /end-free

