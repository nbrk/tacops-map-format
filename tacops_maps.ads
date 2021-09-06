-----------------
-- Tacops_Maps --
-----------------

package Tacops_Maps is

  Parse_Exception : exception;

  type Primary_Terrain is
    (Clear, No_Go_Wheeled, No_Go_Vehicles, No_Go_Everyone, Rough_1, Rough_2,
     Rough_3, Rough_4, Water, Invalid_Value);
  -- Primary terrain that determines mobility, visibility, defense, etc

  type Secondary_Terrain_Flag is
    (Misc_LOS_Block, Elevation, Road, Woods, Town);
  -- Enumeration of flags that can be set/unset in the secondary terrain

  type Secondary_Terrain is array (Secondary_Terrain_Flag) of Boolean;
  -- Secondary terrain that is a set of flags that marks additional features of the given terrain

  type Terrain_Description is record
    Primary   : Primary_Terrain;
    Secondary : Secondary_Terrain;
  end record;
  -- Complete description of terrain in location

  type Terrain_Description_Matrix is
    array
      (Positive range <>, Positive range <>) of Terrain_Description;
  -- Matrix of terrain descriptions covering all the map (downscaled 10:1)

  type Map (Width, Height, Matrix_Cols, Matrix_Rows : Positive) is record
    Number         : Natural range 1 .. 999;
    Overlay_Name   : String (1 .. 7);
    Easting        : Natural;
    Northing       : Natural;
    Terrain_Matrix : Terrain_Description_Matrix
      (1 .. Matrix_Cols, 1 .. Matrix_Rows);
  end record;
  -- Representation of TacOps map

  function Deserialize (Path : String) return Map;
  -- Load .dat map from a file

end Tacops_Maps;
