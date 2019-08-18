#include "TacopsMap.hh"

#include <fstream>

unsigned
TacopsMap::columnRowToIndex(unsigned column, unsigned row) const
{
  return row * getColumns() + column;
}

TacopsMap::TacopsMap()
  : width(0)
  , height(0)
  , columns(0)
  , rows(0)
  , easting(0)
  , northing(0)
{}

void
TacopsMap::loadFile(std::string fileName)
{
  std::fstream fstream;
  fstream.open(fileName.c_str(), std::fstream::in | std::fstream::binary);

  /*
   * The header
   */
  RawHeader header;
  fstream.read(reinterpret_cast<char*>(&header), sizeof(RawHeader));

  if (header.unknown1 != 0 || header.unknown2 != 0)
    throw std::runtime_error("Incorrect file header: 0x02 != 0x0a != 0");

  columns = header.mapCellWidth;
  rows = header.mapCellHeight;
  width = header.mapPixelWidth;
  height = header.mapPixelHeight;
  easting = header.mapUTMEasting;
  northing = header.mapUTMNorthing;
  memcpy(name, header.mapName, sizeof(header.mapName) - 1);
  name[7] = '\0';

  /*
   * Cell data
   */
  for (unsigned r = 0; r < rows; ++r)
    for (unsigned c = 0; c < columns; ++c) {
      RawCell rawCell;
      fstream.read(reinterpret_cast<char*>(&rawCell), sizeof(RawCell));

      /*
       * Mobility byte
       */
      Cell::Mobility mobility;
      switch (rawCell.mobilityByte) {
        case 0x01:
          mobility = Cell::Mobility::NOGO1;
          break;
        case 0x02:
          mobility = Cell::Mobility::NOGO2;
          break;
        case 0x04:
          mobility = Cell::Mobility::NOGO3;
          break;
        case 0x08:
          mobility = Cell::Mobility::ROUGH1;
          break;
        case 0x10:
          mobility = Cell::Mobility::ROUGH2;
          break;
        case 0x18:
          mobility = Cell::Mobility::ROUGH3;
          break;
        case 0x20:
          mobility = Cell::Mobility::ROUGH4;
          break;
        case 0x30:
          mobility = Cell::Mobility::WATER;
          break;
        default:
          mobility = Cell::Mobility::CLEAR;
      }

      /*
       * Features byte
       */
      std::set<Cell::Feature> features;
      if ((rawCell.featuresByte & 0x02) != 0)
        features.insert(Cell::Feature::LOSBLOCK);
      if ((rawCell.featuresByte & 0x08) != 0)
        features.insert(Cell::Feature::ELEVATION);
      if ((rawCell.featuresByte & 0x20) != 0)
        features.insert(Cell::Feature::ROAD);
      if ((rawCell.featuresByte & 0x40) != 0)
        features.insert(Cell::Feature::WOODS);
      if ((rawCell.featuresByte & 0x80) != 0)
        features.insert(Cell::Feature::TOWN);

      /*
       * Assemble the cell
       */
      Cell cell(c, r, mobility, features);

      cells.push_back(cell);
    }
  mapLoadedSignal(this);
}

unsigned
TacopsMap::getWidth() const
{
  return width;
}

unsigned
TacopsMap::getHeight() const
{
  return height;
}

unsigned
TacopsMap::getColumns() const
{
  return columns;
}

unsigned
TacopsMap::getRows() const
{
  return rows;
}

unsigned
TacopsMap::getEasting() const
{
  return easting;
}

unsigned
TacopsMap::getNorthing() const
{
  return northing;
}

char*
TacopsMap::getName() const
{
  return const_cast<char*>(name);
}

unsigned
TacopsMap::getCellWidth() const
{
  return 10;
}

TacopsMap::Cell&
TacopsMap::getCell(unsigned column, unsigned row)
{
  return cells[columnRowToIndex(column, row)];
}

std::vector<TacopsMap::Cell>::const_iterator
TacopsMap::begin() const
{
  return cells.begin();
}

std::vector<TacopsMap::Cell>::const_iterator
TacopsMap::end() const
{
  return cells.end();
}

TacopsMap::Cell::Cell(unsigned column,
                      unsigned row,
                      TacopsMap::Cell::Mobility mobility,
                      std::set<TacopsMap::Cell::Feature> features)
  : column(column)
  , row(row)
  , mobility(mobility)
  , features(features)
{}

void
TacopsMap::setCellMobility(unsigned column,
                           unsigned row,
                           TacopsMap::Cell::Mobility mobility)
{
  Cell oldCell(getCell(column, row));
  Cell cell(column, row, mobility, oldCell.getFeatures());
  cells[columnRowToIndex(column, row)] = cell;

  cellChangedSignal(this, &cell);
}

void
TacopsMap::setCellFeatures(unsigned column,
                           unsigned row,
                           std::set<Cell::Feature> features)
{
  Cell oldCell(getCell(column, row));
  Cell cell(column, row, oldCell.getMobility(), features);
  cells[columnRowToIndex(column, row)] = cell;

  cellChangedSignal(this, &cell);
}

std::set<TacopsMap::Cell::Feature>
TacopsMap::Cell::getFeatures() const
{
  //  using fv = std::vector<TacopsMap::Cell::Feature>;
  //  return const_cast<fv&>(features);
  return features;
}

unsigned
TacopsMap::Cell::getColumn() const
{
  return column;
}

unsigned
TacopsMap::Cell::getRow() const
{
  return row;
}

TacopsMap::Cell::Mobility
TacopsMap::Cell::getMobility() const
{
  return mobility;
}
