#!/bin/bash

# Create sample data files for demonstration
echo "Generating sample Giants data files..."

# Create a sample PDF (using text file as base)
echo "Creating sample documents..."

# Create a simple HTML file that can be converted to PDF
cat > sample-game-report.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Giants vs Cowboys - Game Report</title>
</head>
<body>
    <h1>New York Giants vs Dallas Cowboys</h1>
    <h2>September 10, 2023 - MetLife Stadium</h2>
    
    <h3>Final Score: Giants 40, Cowboys 0</h3>
    
    <p>In a stunning season opener, the New York Giants dominated the Dallas Cowboys 40-0 at MetLife Stadium. The Giants defense recorded 7 sacks and forced 3 turnovers in a historic shutout victory.</p>
    
    <h4>Key Performances:</h4>
    <ul>
        <li>Daniel Jones: 21/32, 289 yards, 2 TD, 0 INT</li>
        <li>Saquon Barkley: 24 carries, 132 yards, 1 TD</li>
        <li>Kayvon Thibodeaux: 3 sacks, 1 forced fumble</li>
        <li>Dexter Lawrence: 2 sacks, 5 tackles</li>
    </ul>
    
    <h4>Game Summary:</h4>
    <p>The Giants set the tone early with a 75-yard touchdown drive on their opening possession. The defense was relentless throughout, holding the Cowboys to just 187 total yards.</p>
    
    <p>This victory marked the Giants' first shutout of the Cowboys since 1995 and their largest margin of victory in the rivalry since 1978.</p>
</body>
</html>
EOF

echo "Sample data files created successfully!"
echo ""
echo "Files created:"
echo "- giants-2023-season-summary.json"
echo "- player-saquon-barkley-stats.json"
echo "- giants-2024-draft-analysis.json"
echo "- metlife-stadium-report.txt"
echo "- sample-game-report.html"
