#ifndef TACOPSMAP_HH
#define TACOPSMAP_HH

#include <cstdint>
#include <memory>
#include <set>
#include <string>
#include <vector>

#include <boost/signals2.hpp>

/**
 * @brief The TacopsMap class
 */
class TacopsMap : std::enable_shared_from_this<TacopsMap>
{
public:
  /**
   * @brief The Cell class
   */
  class Cell
  {
  public:
    enum class Mobility
    {
      CLEAR,
      NOGO1,
      NOGO2,
      NOGO3,
      ROUGH1,
      ROUGH2,
      ROUGH3,
      ROUGH4,
      WATER
    };

    /**
     * @brief The Feature enum
     */
    enum class Feature
    {
      LOSBLOCK,
      ELEVATION,
      ROAD,
      WOODS,
      TOWN
    };

  private:
    unsigned column;
    unsigned row;
    Mobility mobility;
    std::set<Feature> features;

  public:
    Cell(unsigned column,
         unsigned row,
         Mobility mobility,
         std::set<Feature> features);
    unsigned getColumn() const;
    unsigned getRow() const;
    Mobility getMobility() const;
    std::set<Feature> getFeatures() const;
  };

private:
#pragma pack(1)
  struct RawHeader
  {
    uint16_t mapNumber;
    uint32_t unknown1;
    uint16_t mapCellWidth;
    uint16_t mapCellHeight;
    uint32_t unknown2;
    uint16_t mapPixelWidth;
    uint16_t mapPixelHeight;
    uint16_t unknown3; // 0x0001 ?
    uint32_t unknown4;
    uint16_t mapPixelWidthAgain;
    uint16_t mapPixelHeightAgain;
    uint8_t unknown5[20];
    uint16_t unknown6;
    uint16_t mapUTMEasting;
    uint16_t mapUTMNorthing;
    uint16_t mapVersion;
    char mapName[8]; // including final \0
  };

  struct RawCell
  {
    uint8_t featuresByte;
    uint8_t mobilityByte;
  };

#pragma pack(0)

private:
  unsigned width;
  unsigned height;
  unsigned columns;
  unsigned rows;
  unsigned easting;
  unsigned northing;
  char name[8] = "NoName";
  std::vector<Cell> cells;

  unsigned columnRowToIndex(unsigned column, unsigned row) const;

public:
  TacopsMap();

  /**
   * Load a Tacops .dat map file or throw an exception
   * @param fileName the file to load
   */
  void loadFile(std::string fileName) noexcept(false);

  unsigned getWidth() const;
  unsigned getHeight() const;
  unsigned getColumns() const;
  unsigned getRows() const;
  unsigned getEasting() const;
  unsigned getNorthing() const;
  char* getName() const;
  unsigned getCellWidth() const;
  Cell& getCell(unsigned column, unsigned row);

  /**
   * Get iterator to the cells.
   * @return cell iterator
   */
  //  std::vector<Cell>::iterator cellIterator() const;
  std::vector<Cell>::const_iterator begin() const;
  std::vector<Cell>::const_iterator end() const;

  void setCellMobility(unsigned column, unsigned row, Cell::Mobility mobility);
  void setCellFeatures(unsigned column,
                       unsigned row,
                       std::set<Cell::Feature> features);

  /**
   * Signal: A cell was chanded.
   */
  //  boost::signals2::signal<void(std::shared_ptr<TacopsMap> map,
  //                               std::shared_ptr<Cell> cell)>
  boost::signals2::signal<void(TacopsMap* map, Cell* cell)> cellChangedSignal;

  /**
   * @brief mapLoadedSignal
   */
  //  boost::signals2::signal<void(std::shared_ptr<TacopsMap> map)>
  //  mapLoadedSignal;
  boost::signals2::signal<void(TacopsMap* map)> mapLoadedSignal;
};

#endif // TACOPSMAP_HH
