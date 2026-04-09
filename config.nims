# Add src directory to the module search path
switch("path", "src")

# Optimization: Turn off hints to keep the output clean during testing
switch("hints", "off")

# Enable threads as Jazzy is a multi-threaded framework
switch("threads", "on")
