//run this pkill -f "flutter run" 2>/dev/null; pkill -f "flutter_tools" 2>/dev/null; sleep 1 && flutter run -d chrome
      2>&1
#!/bin/bash
pkill -f "flutter run" 2>/dev/null; pkill -f "flutter_tools" 2>/dev/null; sleep 1 && flutter run -d chrome
