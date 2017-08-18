# This file is to redefine the Kernel's methods.
module Kernel
	def `(cmd)
		"call #{cmd}"
	end
	
	def rand(no)
		return 1
	end
end
	