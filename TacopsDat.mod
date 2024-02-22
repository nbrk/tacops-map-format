IMPLEMENTATION MODULE TacopsDat ;

FROM SYSTEM IMPORT BYTE, CARDINAL8, CARDINAL16, BITSET8, ADR;
FROM Storage IMPORT ALLOCATE, DEALLOCATE;
FROM RndFile IMPORT ChanId, OpenResults, OpenOld, Close, SetPos;
FROM RawIO IMPORT Read;
FROM ChanConsts IMPORT opened, old;
FROM IOResult IMPORT ReadResult;
FROM IOConsts IMPORT allRight;
FROM Strings IMPORT Assign;

CONST
   quadrantSize =           10;
   dummyIdent =           "Map000z";    (* when creating custom, incompatible maps *)

TYPE
   Map = POINTER TO MapData;
   TerrainValue = RECORD
                    flags : BITSET8;
                    value : CARDINAL8;
                 END;
   MapData = RECORD
                number               : CARDINAL16;
                numColumns, numRows  : CARDINAL16;
                width, height        : CARDINAL16;
                utmE, utmN           : CARDINAL16;
                version              : CARDINAL16;
                ident                : ARRAY [0..6] OF CHAR;
                terrainArray         : POINTER TO TerrainValue;
             END;

PROCEDURE Load (path : ARRAY OF CHAR; VAR map : Map) : BOOLEAN;
CONST
   (* Offsets into the header *)
   fileOffsetNumber =       00H;
   fileOffsetColumns =      06H;
   fileOffsetRows =         08H;
   fileOffsetWidth =        18H;
   fileOffsetHeight =       1AH;
   fileOffsetUTMEasting =   32H;
   fileOffsetUTMNorthing =  34H;
   fileOffsetVersion =      36H;
   fileOffsetIdent =        38H;
   fileOffsetTerrainArray = 40H;

VAR
   chan : ChanId;
   results : OpenResults;
   data : MapData;
   i : CARDINAL;
   arrayp : POINTER TO ARRAY CARDINAL16 OF TerrainValue;
BEGIN
   OpenOld(chan, path, old, results);
   IF results = opened
   THEN
      (* Read data from the header *)
      (* TODO: check minimum file size before that *)
      SetPos(chan, fileOffsetNumber);
      Read(chan, data.number);
      SetPos(chan, fileOffsetColumns);
      Read(chan, data.numColumns);
      SetPos(chan, fileOffsetRows);
      Read(chan, data.numRows);
      SetPos(chan, fileOffsetWidth);
      Read(chan, data.width);
      SetPos(chan, fileOffsetHeight);
      Read(chan, data.height);
      SetPos(chan, fileOffsetVersion);
      Read(chan, data.version);
      SetPos(chan, fileOffsetIdent);
      Read(chan, data.ident);
      (* TODO: Sanity checks; use the min. size vs values from the header *)
      ALLOCATE(data.terrainArray, SIZE(TerrainValue) * ORD(data.numColumns) * ORD(data.numRows));
      arrayp := ADR(data.terrainArray^);
      FOR i := 0 TO ORD(data.numColumns) * ORD(data.numRows) - 1 BY 1 DO
         SetPos(chan, fileOffsetTerrainArray + SIZE(TerrainValue) * i);
         Read(chan, arrayp^[i]);
      END;
      Close(chan);
      NEW(map);
      map^ := data;             (* XXX *)
      RETURN TRUE;
   ELSE
      RETURN FALSE;
   END;
END Load;

PROCEDURE Unload (VAR map : Map) ;
BEGIN
   DISPOSE(map^.terrainArray);
   DISPOSE(map);
END Unload;

PROCEDURE GetQuadrantCount (map : Map; VAR numCols, numRows : CARDINAL);
BEGIN
   numCols := map^.numColumns;
   numRows := map^.numRows;
END GetQuadrantCount;

PROCEDURE GetPointCount (map : Map; VAR width, height : CARDINAL) ;
BEGIN
   width := map^.width;
   height := map^.height;
END GetPointCount;

PROCEDURE GetIdentString (map : Map; VAR str : ARRAY OF CHAR) ;
BEGIN
   Assign(map^.ident, str);
END GetIdentString;

PROCEDURE GetTerrain (map : Map; column, row : CARDINAL; VAR terrain : Terrain) ;
CONST
   (* .dat terrain types  *)
   clearConst =        00H;
   nogoWheeledConst =  01H;
   nogoVehiclesConst = 02H;
   nogoEveryoneConst = 04H;
   rough1Const =       08H;
   rough2Const =       10H;
   rough3Const =       18H;
   rough4Const =       20H;
   waterConst =        30H;
   (* .dat terrain flags  *)
   (* 00000010 0x02 Misc LOS block *)
   (* 00001000 0x08 hi elevation (E1) *)
   (* 00100000 0x20 road *)
   (* 01000000 0x40 woods *)
   (* 10000000 0x80 town *)
   losBlockBit =       1;
   elevationBit =      3;
   roadBit =           5;
   woodsBit =          6;
   townBit =           7;
VAR
   index : CARDINAL;
   arrayp : POINTER TO ARRAY CARDINAL16 OF TerrainValue;
BEGIN
   (* TODO: check out-of-bounds indexing *)

   index := row * ORD(map^.numColumns) + column;
   arrayp := ADR(map^.terrainArray^);

   (* convert low-level terrain value *)
   CASE arrayp^[index].value OF
      clearConst        : terrain.type := clear;        |
      nogoWheeledConst  : terrain.type := nogoWheeled;  |
      nogoVehiclesConst : terrain.type := nogoVehicles; |
      nogoEveryoneConst : terrain.type := nogoEveryone; |
      rough1Const       : terrain.type := rough1;       |
      rough2Const       : terrain.type := rough2;       |
      rough3Const       : terrain.type := rough3;       |
      rough4Const       : terrain.type := rough4;       |
      waterConst        : terrain.type := water;        |
   ELSE
      terrain.type := clear;      (* XXX silently resets to clear *)
   END;

   (* convert low-level terrain flags *)
   IF losBlockBit IN arrayp^[index].flags
   THEN
      INCL(terrain.flags, losBlock);
   END;
   IF elevationBit IN arrayp^[index].flags
   THEN
      INCL(terrain.flags, elevation);
   END;
   IF roadBit IN arrayp^[index].flags
   THEN
      INCL(terrain.flags, road);
   END;
   IF woodsBit IN arrayp^[index].flags
   THEN
      INCL(terrain.flags, woods);
   END;
   IF townBit IN arrayp^[index].flags
   THEN
      INCL(terrain.flags, town);
   END;

END GetTerrain;

END TacopsDat.
