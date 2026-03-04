Ok, follow these and you should be able to run the app on Windows. Running on iOS is a bit harder, so i can test that here:

1. Install git for Windows, https://git-scm.com/downloads/win  
2. Check if you have VS Code downloaded, if not install here https://code.visualstudio.com/download
3. Install the Flutter extension here: https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter  (it'l open in VS Code)
4. In VS Code, press Ctrl+Shift+P and type "flutter" and select "Flutter: New Project."
    4a. You should see a prompt telling you to locate Flutter SDK on ur computer, click "download SDK" instead, and select anywhere to download it(Somewhere permanent, like in C:Users/[Username]
5. Click clone flutter and wait for it to download (Might take a bit)
6. Make SURE you click Add SDK to Path (VERY IMPORTANT)
7. Restart VS Code
8. Install Visual Studio(different from VS code) from here: https://visualstudio.microsoft.com/thank-you-downloading-visual-studio/?sku=Community&channel=Stable&version=VS18&source=VSLandingPage&cid=2500&passive=false
  8a. During installation, MAKE SURE YOU SELECT DESKTOP DEVELOPMENT WITH C++ BEFORE CLICKING INSTALL (EXTREMELY IMPORTANT)

Aight now you installed everything you need to install. Now just build the app, and it should work. 
To build the app, open the Command prompt and open the code folder location by typing "cd" and the path of the folder. To get path of the folder, right-click on the folder and click copy as path and paste into cmd
Now just type in "flutter pub get", let it load, and type in "flutter run -d windows". After a minute or two, it will auto launch the app.
