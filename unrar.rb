# = Unrar
# A pure ruby implementation of unrar.
# == Features
# * Allows you to stream data from archives, even if they're not complete
# * Cross-Platform
# * No dependencies
#
# == Drawbacks
# * Doesn't yet support compression
# * Doesn't yet support encryption (though the frame work is in place - does anybody know the spec?)
# * Doesn't quite support multi-part archives (nearly there tho!)

class Unrar
  # Flags (in little endian)
  # Archive flags
  ARCH_VOLUME     = 0x0100
  ARCH_LOCKED     = 0x0400
  ARCH_IS_SOLID   = 0x0800
  ARCH_NEW_NAMES  = 0x1000
  ARCH_RECOVERY   = 0x4000
  ARCH_ENC_HEAD   = 0x8000
  ARCH_FIRST_PART = 0x0001
  # File flags
  FILE_CONTINUED  = 0x0100
  FILE_CONTINUES  = 0x0200
  FILE_PASSWORDED = 0x0400
  FILE_IS_SOLID   = 0x1000
  FILE_HIGH_PACK  = 0x0001
  FILE_UNICODED   = 0x0002
  FILE_IS_SALTED  = 0x0004
  FILE_EXT_TIME   = 0x0010
  FILE_MORE_SIZE  = 0x0080
  # OSes
  OSes = ['MS DOS','OS/2','Win32','Unix','Mac OS','BeOS']
  # Attributes
  Attr = [:packed_size,:real_size,:os,:filename]
  
  # Opens a RAR file and parses the header data
  def initialize(filename)
    @fh = open(File.expand_path(filename),"r")
    @eof = false
    # check marker header
    parse_header
  end
  
  # Lists the files in this archive
  def list_contents
    @fh.seek(7)
    parse_header # The archive header
    @files = []
    begin
      while
        file = parse_header(true)
        @files.push file
        # Speed past any data in the file
        @fh.seek(file[:packed_size],IO::SEEK_CUR)
      end
    rescue EOFError
    end
    @files
  end
  
  # Gets the file id of the filename given in the archive
  def getid(fname)
    list_contents if @files.nil?
    @files.each_index do |n|
      if @files[n][:filename] == fname
        fid = n
        break
      end
    end
    raise StandardError, "That file does not exist" if (fid >= @files.length) or fid.nil?
    fid
  end
  
  # Gets you the data from a given file (by file id). Allows you to specify to start from a specific point (so you can access the contained file from any point for streaming) and how many bytes you want extracted
  def extract(fid,offset = 0,amount = nil)
    list_contents if @files.nil?
    fid = getid(fid) if fid.class != Fixnum
    raise StandardError, "That file does not exist" if fid >= @files.length
    amount = @files[fid][:packed_size] - offset if amount.nil?
    @fh.seek(@files[fid][:datastart] + offset)
    @fh.read(amount)
  end
  
  private
  def parse_header(full = false)
    @fh.seek(2,IO::SEEK_CUR) # I don't use the CRC
    details = {}
    
    case @fh.readpartial(1)[0]
    when 0x72
      raise StandardError, "Not a valid RAR file" if @fh.readpartial(4).unpack("vv") != [6689,7]
      return true
    when 0x73
      block = :archive
      full = false
    when 0x74
      block = :file
    when 0x7b
      block = :eof
      raise EOFError
      return
    else
      raise NotImplementedError, "The HEAD_TYPE encountered is not one this library supports"
    end
      
    details[:blockstart] = @fh.pos - 3
    @flags  = @fh.readpartial(2).unpack("v")[0]
    details[:head_size] = @fh.readpartial(2).unpack("v")[0]
    details[:datastart] = details[:blockstart] + details[:head_size]
    
    if ((@flags & FILE_MORE_SIZE != 0) or block == :file)
      details[:packed_size] = @fh.readpartial(4).unpack("V")[0]
      if (@flags & FILE_HIGH_PACK != 0)
        # High packing used (over 2Gb size)
        @fh.seek(21,IO::SEEK_CUR)
        details[:packed_size] += @fh.readpartial(4).unpack("V")[0]
        @fh.seek(-25,IO::SEEK_CUR)
      end
    else
      details[:packed_size] = 0
    end
    
    if full
      details[:real_size] = @fh.readpartial(4).unpack("V")[0]
      details[:os]   = OSes[@fh.readpartial(1).unpack("h")[0].to_i]
      @fh.seek(4,IO::SEEK_CUR) # The file CRC, not used at the moment...
      # DOS date/time
      @fh.readpartial(4).unpack("v").collect{|t| ((t & 0xF800) >> 11) + ((t & 0x07E0) >> 5)*60 + ((t & 0x001F) * 3600)}[0] # - just the time section atm
      @fh.seek(1,IO::SEEK_CUR) # RAR version, ought to check this
      details[:compression_level] = @fh.readpartial(1)[0] - 0x30
      fnamelength = @fh.readpartial(2).unpack("v")[0]
      details[:attributes] = @fh.readpartial(4).unpack("V")[0]
      if (@flags & FILE_HIGH_PACK != 0)
        @fh.seek(4,IO::SEEK_CUR) # We already got the full pack size above
        details[:size] += @fh.readpartial(4).unpack("V")[0] * 0x100000000
      end
      details[:filename] = @fh.readpartial(fnamelength).unpack("a*")[0]
      
    end
    
    # ff to the end of the header
    @fh.seek(details[:blockstart] + details[:head_size])
    return details if full
  end
end