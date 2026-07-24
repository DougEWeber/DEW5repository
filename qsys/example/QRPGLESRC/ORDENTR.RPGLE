      //****************************************************************
      // PROGRAM NAME:   ORDENTR                                       *
      // RELATED FILES:  ORDHDRL1 (LF)                                 *
      //                 ORDDTLL1 (LF)                                 *
      //                 ORDDTLL2 (LF)                                 *
      //                 CUSMSTL1 (LF)                                 *
      //                 INVMSTL1 (LF)                                 *
      //                 ORDESCN  (DSPF)                               *
      // DESCRIPTION:    Order entry. Prompts for a customer (must     *
      //                 already be on file), creates a new order in  *
      //                 the entering state dated today, then lets the*
      //                 user add and delete line items (each item    *
      //                 must already be on file; adding a line       *
      //                 defaults its price from the item's current   *
      //                 price, editable, and reserves the quantity   *
      //                 by adding it to the item's quantity pending; *
      //                 deleting a line releases that reservation).  *
      //                 When done, the whole order is shown for      *
      //                 confirmation. Confirming calls INVSELL to    *
      //                 confirm the sale of each line and moves the  *
      //                 order to the in-process state. Declining, or *
      //                 exiting before that point, fully rolls the   *
      //                 order back (deletes it and every line,       *
      //                 releasing all quantity-pending reservations).*
      //                 PF3 is used to quit the program.             *
      //****************************************************************

     Fordhdrl1  uf a e           k disk
     Forddtll1  uf a e           k disk
     Forddtll2  uf a e           k disk
     Fcusmstl1  if   e           k disk
     Finvmstl1  uf a e           k disk
     Fordescn   cf   e             workstn sfile(linesfl:lineRrn)
     F                                     indds(indicators)

      // Prototype for INVSELL (a separate, non-interactive program --
      // see qsys/example/QRPGLESRC/INVSELL.RPGLE)

     D InvSell         pr                  extpgm('INVSELL')
     D   pItemId                      5a
     D   pQtySold                     7p 0
     D   pSuccess                     1a
     D   pMsg                        50a

      // Field definitions:

     D indicators      ds
     D   exitKey                       n   overlay(indicators:3)
     D   doneKey                       n   overlay(indicators:5)
     D   addKey                        n   overlay(indicators:6)
     D   prevKey                       n   overlay(indicators:12)
     D   sflClear                      n   overlay(indicators:41)
     D   sflCtlDisp                    n   overlay(indicators:42)
     D   sflDisplay                    n   overlay(indicators:43)
     D   itemNotFound                  n   overlay(indicators:51)
     D   custNotFound                  n   overlay(indicators:52)
     D   entryPhase                    n   overlay(indicators:72)
     D   confirmPhase                  n   overlay(indicators:73)
     D   itemValid                     n   overlay(indicators:74)
     D   notValidated                  n   overlay(indicators:75)

     D lineRrn         s              7p 0

      // Working copies -- generating a new order/line ID re-reads a
      // DIFFERENT existing record on the same file, which would
      // otherwise clobber these shared globals before they're used.
     D wOrderId        s              7p 0
     D wCust           s              5p 0
     D wItemId         s              5a
     D wQty            s              7p 0
     D wPrice          s              9p 2
     D sellSuccess     s              1a
     D sellMsg         s             50a
     D itemdesc        s             25a
      //*****************************************************************
      //       MAINLINE                                                 *
      //*****************************************************************

      /free

       exfmt hdrscn;
       dow not exitKey;
          chain(n) cust cusmstl1;
          if not %found(cusmstl1);
             custNotFound = *on;
          else;
             custNotFound = *off;
             exsr CreateOrder;
             exsr LineEntryLoop;
          endif;
          exfmt hdrscn;
       enddo;

       *inlr = *on;
       //****************************************************************
       //    SUBROUTINE - CreateOrder                                   *
       //    PURPOSE    - Create a new order header for the validated   *
       //                 customer, dated today, in the entering state  *
       //****************************************************************
       begsr CreateOrder;
          wCust = cust;

          setll *hival ordhdrl1;
          readp(n) ordhdrl1;
          if %eof(ordhdrl1);
             orderid = 1;
          else;
             orderid = orderid + 1;
          endif;
          wOrderId = orderid;

          cust = wCust;
          orddate = %dec(%char(%date():*iso0):8:0);
          ordstate = 'E';
          write ohlrec1;
       endsr;  // end of subroutine CreateOrder

       //****************************************************************
       //    SUBROUTINE - LineEntryLoop                                 *
       //    PURPOSE    - Let the user add/delete lines on the order    *
       //                 just created, then confirm or cancel it as a *
       //                 whole                                        *
       //****************************************************************
       begsr LineEntryLoop;
          entryPhase = *on;
          confirmPhase = *off;
          exsr ReloadLineSfl;
          dow *on;
             exfmt linectl;
             if exitKey or prevKey;
                exsr RollbackOrder;
                leavesr;
             elseif addKey;
                exsr AddLineSub;
                exsr ReloadLineSfl;
             elseif doneKey;
                leave;
             else;
                // Plain Enter: process any lines marked for delete
                exsr ProcessDeletes;
                exsr ReloadLineSfl;
             endif;
          enddo;

          // Whole-order confirmation
          entryPhase = *off;
          confirmPhase = *on;
          exsr ReloadLineSfl;
          exfmt linectl;
          if exitKey or doneKey or addKey or prevKey;
             // Any function key other than plain Enter declines
             // confirmation (F3/F5/F6/F12 are all still live on this
             // screen format) -- only a bare Enter counts as confirm.
             exsr RollbackOrder;
          else;
             // Plain Enter: accept the order
             exsr AcceptOrder;
          endif;
       endsr;  // end of subroutine LineEntryLoop

       //****************************************************************
       //    SUBROUTINE - ReloadLineSfl                                 *
       //    PURPOSE    - Clear and reload the line subfile from the    *
       //                 order's current detail records, in line ID   *
       //                 order, looking up each item's description    *
       //****************************************************************
       begsr ReloadLineSfl;
          sflClear = *on;
          write linectl;
          sflClear = *off;

          lineRrn = 0;
          setll orderid orddtll2;
          read(n) orddtll2;
          dow not %eof(orddtll2) and orderid = wOrderId;
             sel = *blank;
             chain(n) itemid invmstl1;
             itemdesc = %subst(descr:1:25);
             lineRrn += 1;
             write linesfl;
             read(n) orddtll2;
          enddo;

          // Restore ORDERID/CUST -- the loop above overwrote these shared
          // globals with each detail line's own ORDERID as it read them.
          orderid = wOrderId;
          cust = wCust;

          sflDisplay = (lineRrn > 0);
          sflCtlDisp = *on;
       endsr;  // end of subroutine ReloadLineSfl

       //****************************************************************
       //    SUBROUTINE - AddLineSub                                    *
       //    PURPOSE    - Add one line to the order. First the item ID *
       //                 is validated and its description/current    *
       //                 price are shown; then quantity (required)   *
       //                 and price (defaulted, editable) are entered.*
       //                 Reserves the quantity by adding it to the   *
       //                 item's quantity pending.                    *
       //****************************************************************
       begsr AddLineSub;
          itemid = *blank;
          qty = 0;
          price = 0;
          itemValid = *off;
          notValidated = *on;
          itemNotFound = *off;

          dow *on;
             exfmt lineadd;
             if prevKey;
                leavesr;  // cancel adding this line
             endif;
             if not itemValid;
                chain(n) itemid invmstl1;
                if not %found(invmstl1);
                   itemNotFound = *on;
                   iter;
                endif;
                itemNotFound = *off;
                itemdesc = %subst(descr:1:25);
                price = curprice;
                itemValid = *on;
                notValidated = *off;
                iter;
             else;
                leave;  // quantity/price entered, commit below
             endif;
          enddo;

          // Save the validated line data -- generating the new line ID
          // below reads a DIFFERENT record and would otherwise clobber
          // these shared globals before they're written.
          wItemId = itemid;
          wQty = qty;
          wPrice = price;

          setll *hival orddtll1;
          readp(n) orddtll1;
          if %eof(orddtll1);
             lineid = 1;
          else;
             lineid = lineid + 1;
          endif;

          orderid = wOrderId;
          itemid = wItemId;
          qty = wQty;
          price = wPrice;
          write odlrec1;

          chain wItemId invmstl1;
          qpend = qpend + wQty;
          update imlrec1;
       endsr;  // end of subroutine AddLineSub

       //****************************************************************
       //    SUBROUTINE - ProcessDeletes                                *
       //    PURPOSE    - Delete every line the user marked with 'D',  *
       //                 releasing its quantity-pending reservation   *
       //****************************************************************
       begsr ProcessDeletes;
          readc linesfl;
          dow not %eof(ordescn);
             if sel = 'D';
                chain lineid orddtll1;
                if %found(orddtll1);
                   chain itemid invmstl1;
                   qpend = qpend - qty;
                   update imlrec1;
                   delete odlrec1;
                endif;
             endif;
             readc linesfl;
          enddo;
       endsr;  // end of subroutine ProcessDeletes

       //****************************************************************
       //    SUBROUTINE - AcceptOrder                                   *
       //    PURPOSE    - Confirm the sale of every line via INVSELL,  *
       //                 then move the order to the in-process state  *
       //****************************************************************
       begsr AcceptOrder;
          setll orderid orddtll2;
          read(n) orddtll2;
          dow not %eof(orddtll2) and orderid = wOrderId;
             InvSell(itemid : qty : sellSuccess : sellMsg);
             read(n) orddtll2;
          enddo;

          chain wOrderId ohlrec1;
          ordstate = 'P';
          update ohlrec1;
       endsr;  // end of subroutine AcceptOrder

       //****************************************************************
       //    SUBROUTINE - RollbackOrder                                 *
       //    PURPOSE    - Abandon the order entirely: release every    *
       //                 line's quantity-pending reservation, delete  *
       //                 every line, then delete the header           *
       //****************************************************************
       begsr RollbackOrder;
          setll orderid orddtll2;
          read orddtll2;
          dow not %eof(orddtll2) and orderid = wOrderId;
             chain itemid invmstl1;
             qpend = qpend - qty;
             update imlrec1;
             delete odlrec2;
             read orddtll2;
          enddo;

          chain wOrderId ohlrec1;
          if %found(ordhdrl1);
             delete ohlrec1;
          endif;
       endsr;  // end of subroutine RollbackOrder

      /end-free

