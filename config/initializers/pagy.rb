# Pagy 43+ — overflow and array extras are built-in
# overflow: pages beyond range return empty results by default
# array: use pagy(:offset, array) instead of pagy_array(array)

# Load the series support module so our custom pagination partial can call pagy.send(:series)
require "pagy/toolbox/helpers/support/series"
