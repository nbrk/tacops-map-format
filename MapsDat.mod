IMPLEMENTATION MODULE MapsDat;

FROM Storage IMPORT ALLOCATE, DEALLOCATE, REALLOCATE;
FROM GeneralUserExceptions IMPORT RaiseGeneralException, GeneralExceptions;
IMPORT SYSTEM;
IMPORT SeqFile;
IMPORT RawIO;
IMPORT IOChan;
IMPORT IOResult;
IMPORT ChanConsts;
IMPORT IOConsts;

(*FROM libc IMPORT printf; (* XXX *)*)

TYPE
   (* we will overlay the record below onto the binary file contents *)
   DatFile = RECORD
      name 				: SYSTEM.CARDINAL16;
      unknown0 		: ARRAY [1..4] OF SYSTEM.BYTE;
      numColumns		: SYSTEM.CARDINAL16;
      numRows			: SYSTEM.CARDINAL16;
      unknown1			: ARRAY [1..4] OF SYSTEM.BYTE;
      width				: SYSTEM.CARDINAL16;
      height			: SYSTEM.CARDINAL16;
      unknown2			: ARRAY [1..6] OF SYSTEM.BYTE;
      widthAgain		: SYSTEM.CARDINAL16;
      heightAgain    : SYSTEM.CARDINAL16;
      unknown3			: ARRAY [1..22] OF SYSTEM.BYTE;
      utmEasting		: SYSTEM.CARDINAL16;
      utmNorthing		: SYSTEM.CARDINAL16;
      version			: SYSTEM.CARDINAL16;
      string			: ARRAY [1..8] OF SYSTEM.BYTE;
      terrainArray 	: ARRAY [0..0] OF SYSTEM.CARDINAL16;
   END;


PROCEDURE createFromFile (path : ARRAY OF CHAR; VAR m : Maps.Map);

   (* Read whole file contents into memory *)
   PROCEDURE readFileContents(path : ARRAY OF CHAR;
                              VAR mem : SYSTEM.ADDRESS;
                              VAR memSize : CARDINAL);
   VAR
      cid : SeqFile.ChanId;
      res : SeqFile.OpenResults;
      byte : SYSTEM.BYTE;
      bytep : POINTER TO SYSTEM.BYTE;
   BEGIN
      SeqFile.OpenRead(cid, path, SeqFile.raw + SeqFile.read + SeqFile.old, res);
      IF res = ChanConsts.opened THEN
         memSize := 0;
         LOOP
            RawIO.Read(cid, byte);
            IF IOResult.ReadResult(cid) = IOConsts.allRight THEN
               memSize := memSize + 1;
               IF memSize = 1 THEN
                  ALLOCATE(mem, 1); (* first allocation: can't realloc *)
               ELSE
                  REALLOCATE(mem, memSize);
               END;
               bytep := SYSTEM.ADDADR(mem, memSize - 1);
               bytep^ := byte;
            ELSE
               EXIT;
            END;
         END;
         SeqFile.Close(cid);
      ELSE
         (* error condition: can't open *)
         mem := NIL;
         memSize := 0;
      END;
   END readFileContents;

   TYPE DatFilePtr = POINTER TO DatFile;

   (* Sets all of the map's terrain values from the .dat source *)
   PROCEDURE convertAndSetTerrain (datp : DatFilePtr; VAR m : Maps.Map);

      (* Converts a .dat terrain word to our terrain value *)
      PROCEDURE fromDatTerrain (ter  : SYSTEM.CARDINAL16) : Maps.Terrain;
      CONST
         defaultTerrain = Maps.Terrain{Maps.clear, NIL};
      VAR
         bytes : POINTER TO ARRAY [0..1] OF SYSTEM.CARDINAL8;
         base : SYSTEM.CARDINAL8;
         flagset : SYSTEM.BITSET8;
         t : Maps.Terrain;
      BEGIN
         bytes := SYSTEM.ADR(ter);
         flagset := bytes^[0];
         base := bytes^[1];
         t := defaultTerrain;
(*         printf("convert of hi 0x%x, lo 0x%x\n", hi, lo);*)
         (*
          * Base terrain (hex values).
          *)
         CASE base OF
            | 00H: t.type := Maps.clear;
            | 01H: t.type := Maps.nogoWheeled;
            | 02H: t.type := Maps.nogoVehicles;
            | 04H: t.type := Maps.nogoEveryone;
            | 08H: t.type := Maps.rough1;
            | 10H: t.type := Maps.rough2;
            | 18H: t.type := Maps.rough3;
            | 20H: t.type := Maps.rough4;
            | 30H: t.type := Maps.water;
         ELSE
            t.type := Maps.clear;
         END (* base *);

         (*
          * Terrain flags (bit positions).
          *)
         IF 1 IN flagset THEN
            INCL(t.flags, Maps.hasLosBlock);
         END;
         IF 3 IN flagset THEN
            INCL(t.flags, Maps.hasElevation);
         END;
         IF 5 IN flagset THEN
            INCL(t.flags, Maps.hasRoad);
         END;
         IF 6 IN flagset THEN
            INCL(t.flags, Maps.hasWoods);
         END;
         IF 7 IN flagset THEN
            INCL(t.flags, Maps.hasTown);
         END;
         RETURN t;
      END fromDatTerrain;

   VAR
      col, row : CARDINAL;
      index : CARDINAL;
      terp : POINTER TO SYSTEM.CARDINAL16;
      ter : Maps.Terrain;
      x, y : CARDINAL;
   BEGIN
      FOR row := 0 TO (datp^.numRows - 1) DO
         FOR col := 0 TO (datp^.numColumns - 1) DO
            index := row * ORD(datp^.numColumns) + col;
            terp := SYSTEM.ADDADR(SYSTEM.ADR(datp^.terrainArray),
                                    index * SIZE(terp^));
(*            printf("Dat terrain at %d, %d: 0x%x\n", col, row, terp^);*)
            (* convert .dat terrain value to our terrain value *)
            ter := fromDatTerrain(terp^);
            FOR y := 10 * row TO 10 * row + (10 - 1) DO
               FOR x := 10 * col TO 10 * col + (10 - 1) DO
                  IF (x < ORD(datp^.width)) AND (y < ORD(datp^.height)) THEN
                     (* check for .dat with 10 * grid >= width/height *)
                     Maps.setTerrain(m, x, y, ter);
                  END;
               END;
            END;
         END;
      END;
   END convertAndSetTerrain;

VAR
   datSize : CARDINAL;
   datp : DatFilePtr;
BEGIN
   readFileContents(path, datp, datSize);
   IF datSize > 0 THEN
(*      printf("Map '%s' %d x %d (%d cols x %d rows) version %d\n",
         datp^.string, datp^.width, datp^.height, datp^.numColumns, datp^.numRows, datp^.version);*)
      (*
       * Initialize a new map, set terrain values from the .dat and dispose it.
       *)
      Maps.create(datp^.width, datp^.height, m);
      convertAndSetTerrain(datp, m);
      DEALLOCATE(datp, datSize);
   ELSE
      (* zero-size means I/O error of some kind or an empty file *)
      RaiseGeneralException(problem, "I/O error or empty .dat file");
   END;
END createFromFile;

BEGIN

(* Module initialization *)

END MapsDat.
