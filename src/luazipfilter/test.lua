
local ltn12 = require("ltn12")
local zip = require("zipfilter")


function zip_file_sink(dir)
	local fh = nil

	return function(chunk)
		if chunk == nil then
			if fh then
				fh:close()
				fh = nil
			end

		elseif type(chunk) == "table" then
			if fh then
				fh:close()
				fh = nil
			end

			local filename = dir .. string.gsub(chunk.filename, "/", "_")
			print("filename=" .. filename)

			fh = io.open(filename, "w")

		else
			if fh == nil then
				-- error no output file
				return nil
			end

			fh:write(chunk)
		end

		return 1
	end
end


local filter = zip.filter()

ltn12.pump.all(
	ltn12.source.file(io.open("test.zip")),
	ltn12.sink.chain(filter, zip_file_sink("foo/"))
)

