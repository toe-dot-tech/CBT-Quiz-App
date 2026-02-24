#!/bin/bash

## 2. Make it Executable

## You need to give the script permission to run. In your terminal, type:
## chmod +x deploy_web.sh

## 3. Run the Update

## Now, whenever you change your student code, just run this command:

## ./deploy_web.sh

















## Critical Step for Linux (Permission Check)

## Sometimes Linux prevents the Dart server from writing to the CSV file if it doesn't have "Write" ## permissions in that folder.

## To ensure the server can actually save the results (which updates your graph), run this in your ## project folder:
## Bash

## chmod 777 .

echo "🚀 Starting Flutter Web Build..."
flutter build web --release --base-href "/"

echo "🧹 Cleaning old assets..."
rm -rf assets/web/*

echo "📂 Copying new build to assets/web..."
mkdir -p assets/web
cp -r build/web/* assets/web/

echo "✅ Done! Your student UI is updated and linked."
