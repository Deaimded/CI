echo "$CREDENTIALS" > ~/.git-credentials

git clone $REPO kernel --depth=5
cd kernel
curl https://raw.githubusercontent.com/Deaimded/CI/main/build.sh | bash
