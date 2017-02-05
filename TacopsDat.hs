module TacopsDat where

import Data.Binary
import Data.Binary.Get
import Data.Word
import Data.Bits
import Control.Monad
import qualified Data.ByteString.Lazy as B
import qualified Data.ByteString.Lazy.Char8 as B8

data DatStruct = DatStruct
  { datNumber :: Int
  , datWidth :: Int
  , datHeight :: Int
  , datName :: String
  , datCells :: [DatCell]
  , datCellsBS :: B.ByteString
  } deriving (Show)

instance Binary DatStruct where
  put = undefined
  get = do
      mapnum <- getWord16le
      skip 4
      xsize <- getWord16le
      ysize <- getWord16le
      skip 46
      mapname <- getLazyByteString 8
      let width = fromEnum xsize
          height = fromEnum ysize
      celldata <- getRemainingLazyByteString
      let cells = bsToDatCells $ B.unpack celldata
      return (DatStruct (fromEnum mapnum) width height (B8.unpack mapname) cells celldata)

data PrimaryTerrain = Clear
                    | NOGO1 -- no-go for wheeled
                    | NOGO2 -- no-go for wheeled & tracked
                    | NOGO3 -- no-go for vehicles & dismounts
                    | Rough1
                    | Rough2
                    | Rough3
                    | Rough4
                    | Water
       deriving (Eq, Show)

-- | list of secondary terrains
data SecondaryTerrain = Losblock
                      | Road
                      | Woods
                      | Town
       deriving (Eq, Show)

data Elevation = E0 | E1 deriving (Show)

data DatCell = DatCell PrimaryTerrain [SecondaryTerrain] Elevation
  deriving (Show)

bsToDatCells :: [Word8] -> [DatCell]
bsToDatCells (w1:w2:ws) = bytesToDatCell (w1,w2) : bsToDatCells ws
bsToDatCells (w:[]) = []


-- parse a cell of two Word8s into a DatCell
bytesToDatCell :: (Word8, Word8) -> DatCell
bytesToDatCell (w1,w2) = DatCell prit sects elev
    where prit = case w2 of
                   0x00 -> Clear
                   0x01 -> NOGO1
                   0x02 -> NOGO2
                   0x04 -> NOGO3
                   0x08 -> Rough1
                   0x10 -> Rough2
                   0x18 -> Rough3
                   0x20 -> Rough4
                   0x30 -> Water
          elev = case (w1 .&. 0x08) of
                   0 -> E0
                   _ -> E1
          sects = byteToSects (w1 .&. (complement 0x08))

-- parse secondary terrains
byteToSects :: Word8 -> [SecondaryTerrain]
byteToSects w = case w .&. 0xff of
                          0x02 -> [Losblock] ++ byteToSects (xor w 0x02)
                          0x20 -> [Road] ++ byteToSects (xor w 0x20)
                          0x40 -> [Woods] ++ byteToSects (xor w 0x40)
                          0x80 -> [Town] ++ byteToSects (xor w 0x80)
                          otherwise -> []

fromFile :: String -> IO DatStruct
fromFile fn = do
  decodeFile fn
