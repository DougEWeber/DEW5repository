/****************************************************************/
/* PROGRAM NAME:   INVSELTST                                    */
/* RELATED PGMS:   INVSELL                                      */
/* DESCRIPTION:    Test-support wrapper for INVSELL, not part   */
/*                 of the inventory feature itself. Exists      */
/*                 because the generic CALL command's PARM      */
/*                 values don't reliably produce valid packed   */
/*                 decimal data for INVSELL's QtySold parameter */
/*                 (confirmed: MCH1202 decimal-data error) --   */
/*                 CL's CHGVAR does that character-to-decimal   */
/*                 conversion correctly, and all four of THIS   */
/*                 program's own parameters are plain character,*/
/*                 so calling this one via CALL is reliable.    */
/*                 Echoes INVSELL's Success/Msg output back to  */
/*                 the caller's job via SNDPGMMSG so they're    */
/*                 visible on the Command Entry screen.         */
/****************************************************************/

             PGM        PARM(&ITEMID &QTYCHAR &SUCCESS &MSG)

             DCL        VAR(&ITEMID)  TYPE(*CHAR) LEN(5)
             DCL        VAR(&QTYCHAR) TYPE(*CHAR) LEN(7)
             DCL        VAR(&QTY)     TYPE(*DEC)  LEN(7 0)
             DCL        VAR(&SUCCESS) TYPE(*CHAR) LEN(1)
             DCL        VAR(&MSG)     TYPE(*CHAR) LEN(50)

             CHGVAR     VAR(&QTY) VALUE(&QTYCHAR)

             CALL       PGM(INVSELL) PARM(&ITEMID &QTY &SUCCESS &MSG)

             SNDPGMMSG  MSG('INVSELTST result: Success=' *CAT &SUCCESS *BCAT +
                          'Msg=' *CAT &MSG) TOPGMQ(*EXT) MSGTYPE(*INFO)

             ENDPGM
