#!/usr/bin/env bash

echo "$(tput setaf 3)" # Set the prerequisites to yellow
echo "WARNING: Before beginning, you will need the following prerequisites:"
echo ""
echo "    0) SSH access to your hosting provider"
echo ""
echo "          Example: You should be able to \`ssh\` to <SUBDOMAIN>."
echo ""
echo "    1) An empty GitHub repo - the repo name should match the name of the (sub)domain."
echo ""
echo "          Example: https://github.com/<USERNAME>/<SUBDOMAIN> should exist and be empty."
echo ""
echo "    2) A (sub)domain already created on your hosting provider - the document root should exist off of the users home directory."
echo ""
echo "          Example: ~/<SUBDOMAIN> should exist on your remote host."
echo ""
echo "$(tput sgr0)" # Reset the colors
tput setaf 4        # Change color to blue
read -p "...Press enter to continue once all the prerequisites are satisfied..."
tput sgr0 || tput me # Reset the colors

# UNIVERSAL VARIABLES
SECRET_ACCESS_TOKEN=$(sed "s/[^a-zA-Z0-9]//g" <<<$(openssl rand -base64 128) | head -c 65)
GH_MAIN_BRANCH=main

# GET USER INPUT
read -p "Enter your GitHub username [ex: ChrisCarini]: " GH_USERNAME
read -p "Enter the subdomain [ex:foo.example.com]: " SUBDOMAIN
read -p "Enter your email [ex: email@example.com]: " CONTACT_EMAIL
read -p "[Remote Host] Enter the SSH username for the remote host $SUBDOMAIN: " REMOTE_HOST_USERNAME
HOSTING_HOMEDIR=$(ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "pwd")

echo "##########################"
echo "# Creating initial files #"
echo "##########################"
echo "Creating [README.md] file..."
cat <<EOF >README.md
# \`$SUBDOMAIN\`

This repository is the backing to [$SUBDOMAIN](https://$SUBDOMAIN).

### Development Notes

#### git Submodules

This repository makes use of git submodules. Specifically, we use [simple-php-git-deploy](https://github.com/markomarkovic/simple-php-git-deploy)
to automatically deploy changes to this repository to our host.

When cloning this directory, run the below command to automatically initialize and update the submodules:
  \`\`\`shell script
  git clone --recurse-submodules git@github.com:$GH_USERNAME/$SUBDOMAIN.git
  \`\`\`

You will have to create the \`deploy-config.php\` file and set the properties accordingly.
  \`\`\`shell script
  cp deploy-hooks/deploy-config.example.php deploy-hooks/deploy-config.php
  vi deploy-hooks/deploy-config.php
  \`\`\`
(**Note:** We explicitly exclude this file from SCM, so you will have to SCP it over to the host.)

See [git-scm.com - 7.11 Git Tools - Submodules](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for
a good primer on git submodules.
EOF

echo "Creating [.gitignore] file..."
cat <<EOF >.gitignore
.idea/
VERSION
**/deploy-config.php
EOF

echo "Creating [.htaccess] file..."
cat <<EOF >.htaccess
Options -Indexes

RewriteEngine On

# Force site to redirect to HTTPS instead of HTTP
RewriteCond %{HTTPS} !=on
RewriteRule ^(.*)$ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]

# Return 404 for certain files/directories
RedirectMatch 404 /\.git
RedirectMatch 404 \.gitignore
RedirectMatch 404 \.gitmodules

RedirectMatch 404 README\.md
RedirectMatch 404 VERSION
EOF

echo "Checking if remote directory [$HOSTING_HOMEDIR/$SUBDOMAIN] exists..."
if ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "[ -d $HOSTING_HOMEDIR/$SUBDOMAIN ]"; then
  echo "Remote directory [$HOSTING_HOMEDIR/$SUBDOMAIN] found! Copying files into local directory..."
  rsync -av -e ssh --exclude='.well-known' --exclude='.git' $REMOTE_HOST_USERNAME@$SUBDOMAIN:$HOSTING_HOMEDIR/$SUBDOMAIN/ ./
fi

echo "Initializing git repo..."
git init

echo "Adding simple-php-git-deploy submodule..."
git submodule add https://github.com/markomarkovic/simple-php-git-deploy.git deploy-hooks

echo "Adding initial files..."
git add README.md
git add .gitignore
git add .htaccess
git add deploy-hooks
git add ./

git commit -m "Initial commit for $SUBDOMAIN"
git branch -M $GH_MAIN_BRANCH
git remote add origin git@github.com:$GH_USERNAME/$SUBDOMAIN.git

echo "Creating [deploy-hooks/deploy-config.php] file..."
cat <<EOF >deploy-hooks/deploy-config.php
<?php
/**
* Deployment configuration - see deploy-config.example.php for full docs.
*
* @version 1.3.1
*/

define('SECRET_ACCESS_TOKEN', '$SECRET_ACCESS_TOKEN');
define('REMOTE_REPOSITORY', 'https://github.com/$GH_USERNAME/$SUBDOMAIN.git');
define('BRANCH', '$GH_MAIN_BRANCH');
define('TARGET_DIR', '$HOSTING_HOMEDIR/$SUBDOMAIN/');
define('DELETE_FILES', false);
define('EXCLUDE', serialize(array(
'.git',
)));
define('TMP_DIR', '$HOSTING_HOMEDIR/tmp/spgd-'.md5(REMOTE_REPOSITORY).'/');
define('CLEAN_UP', false);
define('VERSION_FILE', TMP_DIR.'VERSION');
define('TIME_LIMIT', 30);
define('BACKUP_DIR', '$HOSTING_HOMEDIR/$(echo $SUBDOMAIN)_backups/');
define('USE_COMPOSER', false);
define('COMPOSER_OPTIONS', '--no-dev');
define('COMPOSER_HOME', false);
define('EMAIL_ON_ERROR', '$CONTACT_EMAIL');
EOF

echo "Pushing initial commit to [$GH_MAIN_BRANCH] branch..."
git push -u origin $GH_MAIN_BRANCH

echo "Visit the below URL to configure a webhook for this repo."
echo ""
echo " URL: https://github.com/$GH_USERNAME/$SUBDOMAIN/settings/hooks/new"
echo " SETTINGS:"
echo "    - Payload URL:      https://$SUBDOMAIN/deploy-hooks/deploy.php?sat=$SECRET_ACCESS_TOKEN"
echo "    - Content Type:     application/x-www-form-urlencoded"
echo "    - Secret:           EMPTY"
echo "    - SSL verification: Enable SSL Verification"
echo "    - Which events?:    Just the push event"
echo "    - Active:           Check"
echo ""
echo ""
tput setaf 1 # Change color to red
read -p "...Press enter once you have configured the webhook to continue..."
tput sgr0 || tput me # Reset colors

echo "Checking if remote directory [$HOSTING_HOMEDIR/$SUBDOMAIN] exists..."
if ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "[ -d $HOSTING_HOMEDIR/$SUBDOMAIN ]"; then
  echo "Remote directory [$HOSTING_HOMEDIR/$SUBDOMAIN] found! Moving into backup location..."
  ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "mv $HOSTING_HOMEDIR/$SUBDOMAIN $HOSTING_HOMEDIR/$(echo $SUBDOMAIN)_PRE_SCRIPT_BACKUP"
fi

echo "Checkout [$GH_USERNAME/$SUBDOMAIN] on your remote hosting to [$HOSTING_HOMEDIR/$SUBDOMAIN]..."
ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "git clone --recurse-submodules git@github.com:$GH_USERNAME/$SUBDOMAIN.git $HOSTING_HOMEDIR/$SUBDOMAIN"

echo "Copying local file: [deploy-hooks/deploy-config.php] to remote host: [$HOSTING_HOMEDIR/$SUBDOMAIN/deploy-hooks/deploy-config.php]..."
scp deploy-hooks/deploy-config.php $REMOTE_HOST_USERNAME@$SUBDOMAIN:$HOSTING_HOMEDIR/$SUBDOMAIN/deploy-hooks/deploy-config.php

echo "Creating remote backup directory at [$HOSTING_HOMEDIR/$(echo $SUBDOMAIN)_backups]..."
ssh $REMOTE_HOST_USERNAME@$SUBDOMAIN "mkdir $HOSTING_HOMEDIR/$(echo $SUBDOMAIN)_backups"

tput setaf 2 # Change color to green
echo "##############"
echo "#  Success!  #"
echo "##############"
tput sgr0 || tput me # Reset the colors
echo ""
echo "You are now able to push to [$GH_USERNAME/$SUBDOMAIN] and have the remote repo at [$SUBDOMAIN] automatically pull in changes."
