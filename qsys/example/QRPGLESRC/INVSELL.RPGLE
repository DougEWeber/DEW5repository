      //****************************************************************
      // PROGRAM NAME:   INVSELL                                       *
      // RELATED FILES:  INVMSTL1 (LF)                                 *
      // DESCRIPTION:    Callable API: confirms that a quantity of an  *
      //                 inventory item has been sold. Checks that the *
      //                 quantity requested is currently pending (held *
      //                 on a building order), and if so reduces both  *
      //                 quantity on hand and quantity pending by it.  *
      //                 Not called interactively -- CALL INVSELL with *
      //                 the parameters below, e.g. from CL or another *
      //                 RPG program.                                  *
      //
      // Parameters (in order):
      //   1  ItemId    5A   in   item ID to sell against
      //   2  QtySold   7P0  in   quantity being confirmed as sold
      //   3  Success   1A   out  'Y' if confirmed, 'N' if rejected
      //   4  Msg      50A   out  blank on success; reason on failure
      //****************************************************************

     Finvmstl1  uf a e           k disk

      // Field definitions:

     D ItemId          s              5a
     D QtySold         s              7p 0
     D Success         s              1a
     D Msg             s             50a

      // Entry parameters. ItemId has its own D-spec (above) rather
      // than relying on invmstl1's externally-described field of the
      // same name -- using the external field directly as an *ENTRY
      // PLIST parameter didn't reliably size the entry interface (the
      // chain below would silently fail to find real records). CHAIN
      // still works fine keying on a plain standalone field.

     C     *entry        plist
     C                   parm                    ItemId
     C                   parm                    QtySold
     C                   parm                    Success
     C                   parm                    Msg
      //*****************************************************************
      //       MAINLINE                                                 *
      //*****************************************************************

      /free

       success = 'N';
       msg = *blank;

       chain ItemId imlrec1;
       if not %found(invmstl1);
          msg = 'ITEM NOT ON FILE';
       elseif qpend < qtysold;
          unlock invmstl1;
          msg = 'INSUFFICIENT QUANTITY PENDING';
       else;
          qoh = qoh - qtysold;
          qpend = qpend - qtysold;
          update imlrec1;
          success = 'Y';
       endif;

       *inlr = *on;

      /end-free

