/*
 * To change this license header, choose License Headers in Project Properties.
 * To change this template file, choose Tools | Templates
 * and open the template in the editor.
 */

package nbrk.tacopsmapeditor;

import java.io.*;
import java.util.*;

public class TacopsMap {
	private String fileName;
	private short name;
	private short width;
	private short height;
	private short cellColumns;
	private short cellRows;
	private ArrayList<Cell> cellData;

	public static class Cell {
		private int column;
		private int row;
		private Mobility mobility;
		private Feature[] features;
		
		public static enum Mobility {
			CLEAR,
			NOGO1,
			NOGO2,
			NOGO3,
			ROUGH1,
			ROUGH2,
			ROUGH3,
			ROUGH4,
			WATER
		}

		public static enum Feature {
			LOSBLOCK,
			ELEVATION,
			ROAD,
			WOODS,
			TOWN
		}

		public Cell(int column, int row, Mobility mobility, Feature[] features) {
			this.column = column;
			this.row = row;
			this.mobility = mobility;
			this.features = features;
		}

		public int getColumn() {
			return column;
		}

		public int getRow() {
			return row;
		}

		public Mobility getMobility() {
			return mobility;
		}

		public Feature[] getFeatures() {
			return features;
		}
	}

	private static short readu16be(RandomAccessFile f) throws IOException{
		return Short.reverseBytes((short)f.readUnsignedShort());
	}

	public TacopsMap(String fileName) throws FileNotFoundException, IOException {
		RandomAccessFile f = new RandomAccessFile(fileName, "r");
		this.cellData = new ArrayList<>();
		this.fileName = fileName;
		this.name = readu16be(f);
		f.seek(0x06);
		this.cellColumns = readu16be(f);
		this.cellRows = readu16be(f);
		f.seek(0x0e);
		this.width = readu16be(f);
		this.height = readu16be(f);
		f.seek(0x40);
		for (int r = 0; r < cellRows; r++)
			for (int c = 0; c < cellColumns; c++) {
				byte mobilityByte;
				byte featuresByte;
				Cell cell;
				Cell.Mobility mobility;
				ArrayList<Cell.Feature> features;

				mobilityByte = (byte)f.readUnsignedByte();
				featuresByte = (byte)f.readUnsignedByte();

				switch(mobilityByte) {
					case 0x01: mobility = Cell.Mobility.NOGO1;
					case 0x02: mobility = Cell.Mobility.NOGO2;
					case 0x04: mobility = Cell.Mobility.NOGO3;
					case 0x08: mobility = Cell.Mobility.ROUGH1;
					case 0x10: mobility = Cell.Mobility.ROUGH2;
					case 0x18: mobility = Cell.Mobility.ROUGH3;
					case 0x20: mobility = Cell.Mobility.ROUGH4;
					case 0x30: mobility = Cell.Mobility.WATER;
					default: mobility = Cell.Mobility.CLEAR;
				}

				features = new ArrayList<>();
				if ((featuresByte & 0x02) != 0) features.add(Cell.Feature.LOSBLOCK);
				if ((featuresByte & 0x08) != 0) features.add(Cell.Feature.ELEVATION);
				if ((featuresByte & 0x20) != 0) features.add(Cell.Feature.ROAD);
				if ((featuresByte & 0x40) != 0) features.add(Cell.Feature.WOODS);
				if ((featuresByte & 0x80) != 0) features.add(Cell.Feature.TOWN);

				cell = new Cell(c, r, mobility, features.toArray(new Cell.Feature[0]));
				this.cellData.add(cell);
			}
	}

	public String getFileName() {
		return fileName;
	}

	public int getName() {
		return name;
	}

	public int getWidth() {
		return width;
	}

	public int getHeight() {
		return height;
	}

	public int getCellColumns() {
		return cellColumns;
	}

	public int getCellRows() {
		return cellRows;
	}

	public ArrayList<Cell> getCellData() {
		return cellData;
	}

}
