# Firebase Functions

## Setup
- Firebase > Functions > Start
```bash
$ npm install -g firebase-tools
```

> [!Tip]
> 'Firebase Functions' requires the 'Blaze' plan, which allows you to pay as you use. You can get Free $300 credit for 3 Months in GCP.
> https://firebase.blog/posts/2024/11/claim-300-to-get-started

- Project Start
```bash
$ cd ./Backend
$ firebase init

? Which Firebase features do you want to set up for this directory? Press Space to select features, then Enter to confirm your choices.
- Firestore
- Functions

=== Project Setup
...

? Please select an option:
- Use an existing project

? Select a default Firebase project for this directory
- [Project ID](FirebaseChatting)

? Please select the location of your Firestore database:
- asia-northeast3

? What file should be used for Firestore Rules?
- firestore.rules(Default)

? What file should be used for Firestore indexes?
- firestore.indexes.json(Default)

? What language would you like to use to write Cloud Functions?
- Typescript

? Do you want to use ESLint to catch probable bugs and enforce style?
- Y

? Do you want to install dependencies with npm now?
- Y
```

- Build & Deploy
```bash
$ cd functions
$ npm run build
$ firebase deploy --only functions
```

