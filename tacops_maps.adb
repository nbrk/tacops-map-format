with Ada.Direct_IO;
with Interfaces.C;            use Interfaces.C;
with Interfaces.C.Extensions; use Interfaces.C.Extensions;
with System;

package body Tacops_Maps is

  type Terrain_Struct is record
    Secondary : Unsigned_8;
    Primary   : Unsigned_8;
  end record;
  pragma Pack (Terrain_Struct);

  type Header_Struct is record
    Number        : Unsigned_16;
    Unknown1      : Unsigned_32;
    Matrix_Width  : Unsigned_16;
    Matrix_Height : Unsigned_16;
    Unknown2      : Unsigned_32;
    Width         : Unsigned_16;
    Height        : Unsigned_16;
    Unknown3      : Unsigned_64;
    Unknown4      : Unsigned_64;
    Unknown5      : Unsigned_64;
    Unknown6      : Unsigned_64;
    Easting       : Unsigned_16;
    Northing      : Unsigned_16;
    Version       : Unsigned_16;
    Map_Name      : String (1 .. 7);
  end record;
  pragma Pack (Header_Struct);

  function Make_Terrain_Description
    (Raw_Terrain : Terrain_Struct) return Terrain_Description
  is
    Terrain : Terrain_Description :=
                Terrain_Description'
                  (Primary => Invalid_Value, Secondary => (others => False));
  begin
    case Raw_Terrain.Primary is
      when 16#0# =>
        Terrain.Primary := Clear;
      when 16#1# =>
        Terrain.Primary := No_Go_Wheeled;
      when 16#2# =>
        Terrain.Primary := No_Go_Vehicles;
      when 16#4# =>
        Terrain.Primary := No_Go_Everyone;
      when 16#8# =>
        Terrain.Primary := Rough_1;
      when 16#10# =>
        Terrain.Primary := Rough_2;
      when 16#18# =>
        Terrain.Primary := Rough_3;
      when 16#20# =>
        Terrain.Primary := Rough_4;
      when 16#30# =>
        Terrain.Primary := Water;
      when others =>
        Terrain.Primary := Invalid_Value;
    end case;

    if (Raw_Terrain.Secondary and 16#02#) /= 0 then
      Terrain.Secondary (Misc_LOS_Block) := True;
    end if;
    if (Raw_Terrain.Secondary and 16#08#) /= 0 then
      Terrain.Secondary (Elevation) := True;
    end if;
    if (Raw_Terrain.Secondary and 16#20#) /= 0 then
      Terrain.Secondary (Road) := True;
    end if;
    if (Raw_Terrain.Secondary and 16#40#) /= 0 then
      Terrain.Secondary (Woods) := True;
    end if;
    if (Raw_Terrain.Secondary and 16#80#) /= 0 then
      Terrain.Secondary (Town) := True;
    end if;

    return Terrain;
  end Make_Terrain_Description;


  -----------------
  -- Deserialize --
  -----------------

  function Deserialize (Path : String) return Map is
    package C renames Interfaces.C;
    package Header_Struct_IO is new Ada.Direct_IO (Header_Struct);
    File : Header_Struct_IO.File_Type;
  begin
    Header_Struct_IO.Open (File, Header_Struct_IO.In_File, Path);
    declare
      Hdr : Header_Struct;
    begin
      Header_Struct_IO.Read (File, Hdr);
      Header_Struct_IO.Close (File);

      --
      -- Use the header
      --
      declare
        M : Map
          (Width       => Positive (Hdr.Width), Height => Positive (Hdr.Height),
           Matrix_Cols => Positive (Hdr.Matrix_Width),
           Matrix_Rows => Positive (Hdr.Matrix_Height));
      begin
        M.Number       := Positive (Hdr.Number);
        M.Easting      := Natural (Hdr.Easting);
        M.Northing     := Natural (Hdr.Northing);
        M.Overlay_Name := Hdr.Map_Name;

        --
        -- Clear the matrix to invalid terrains
        --
        for R in 1 .. M.Matrix_Rows loop
          for C in 1 .. M.Matrix_Cols loop
            M.Terrain_Matrix (C, R) :=
              (Invalid_Value, (others => False));
          end loop;
        end loop;

        --
        -- Read the array (need File/IO from other package instance)
        --
        declare
          package Terrain_Struct_IO is new Ada.Direct_IO (Terrain_Struct);
          File        : Terrain_Struct_IO.File_Type;
          Raw_Terrain : Terrain_Struct;
        begin
          Terrain_Struct_IO.Open (File, Terrain_Struct_IO.In_File, Path);
          Terrain_Struct_IO.Set_Index (File, 32); -- skip 32 x (2 * int16)

          --  for Offset in 1 .. (M.Matrix_Cols * M.Matrix_Rows) loop
          --     declare
          --        Col : Integer := Offset rem M.Matrix_Cols;
          --        Row : Integer := Offset / M.Matrix_Cols;
          --     begin
          --        -- XXX
          --        if Col = 0 then
          --           Col := M.Matrix_Cols;
          --        end if;
          --        if Row = 0 then
          --           Row := M.Matrix_Rows;
          --        end if;
          --        Terrain_Struct_IO.Read (File, Raw_Terrain);
          --        M.Terrain_Matrix (Col, Row) :=
          --          Make_Terrain_Description (Raw_Terrain);
          --     end;
          --  end loop;

          for R in 1 .. M.Matrix_Rows loop
            for C in 1 .. M.Matrix_Cols loop
              Terrain_Struct_IO.Read (File, Raw_Terrain);
              M.Terrain_Matrix (C, R) :=
                Make_Terrain_Description (Raw_Terrain);
            end loop;
          end loop;

          Terrain_Struct_IO.Close (File);
        end;
        return M;
      end;
    end;
  end Deserialize;

end Tacops_Maps;
