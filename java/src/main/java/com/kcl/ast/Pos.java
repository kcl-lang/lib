package com.kcl.ast;

import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.annotation.JsonDeserialize;
import com.fasterxml.jackson.databind.annotation.JsonSerialize;

@JsonInclude(JsonInclude.Include.NON_NULL)
@JsonSerialize
@JsonDeserialize
public class Pos {
	@JsonProperty("filename")
	private String filename;

	@JsonProperty("line")
	private long line;

	@JsonProperty("column")
	private long column;

	@JsonProperty("end_line")
	private long endLine;

	@JsonProperty("end_column")
	private long endColumn;

	public Pos(String filename, long line, long column, long endLine, long endColumn) {
		this.filename = filename;
		this.line = line;
		this.column = column;
		this.endLine = endLine;
		this.endColumn = endColumn;
	}

	public String getFilename() {
		return filename;
	}

	public void setFilename(String filename) {
		this.filename = filename;
	}

	public long getLine() {
		return line;
	}

	public void setLine(long line) {
		this.line = line;
	}

	public long getColumn() {
		return column;
	}

	public void setColumn(long column) {
		this.column = column;
	}

	public long getEndLine() {
		return endLine;
	}

	public void setEndLine(long endLine) {
		this.endLine = endLine;
	}

	public long getEndColumn() {
		return endColumn;
	}

	public void setEndColumn(long endColumn) {
		this.endColumn = endColumn;
	}

}
