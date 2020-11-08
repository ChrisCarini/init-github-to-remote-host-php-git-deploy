# Initialize a new GitHub repo to deploy changes to a remote host

This repository provides directions (and, better yet, a quick script) on how to create and configure a 
new GitHub repository to sync / deploy changes to a remote host.

We leverage [markomarkovic/simple-php-git-deploy](https://github.com/markomarkovic/simple-php-git-deploy) for the php/git deploy hooks.

## Pre-req
You need to have:
1) **A HTTPS domain already created on your hosting provider** - 
subdomains ok; the webserver document root for the domain should exist off of the users home directory; 
the document root can have contents, we will attempt to back them up locally and remotely.
     
    **Example:**
    - `https://<DOMAIN>/` should load.
    - `~/<DOMAIN>` should exist on your remote host. If files already exist in this directory, the 
    `install.sh` script will back them up on the remote host, and make them part of the initial commit to 
    the GitHub repo.

1) **SSH access to your hosting provider**

    **Example:** You should be able to `ssh` to `<DOMAIN>`.

1) **An empty GitHub repo** - the repo name should match the name of the (sub)domain.
      
    **Example:** `https://github.com/<USERNAME>/<DOMAIN>` should exist and be empty.


## Quick Script
Change directories to where you want your GitHub repo to be initialized locally, and run the `install.sh` 
script found in this directory.

Try to use the script instead of the manual steps below - automation is nice. 

## Manual Steps
1) Create new git repo on local machine (`git init`)
1) Copy any existing files from your remote host into the new git repo you just created above
1) Add the submodule php git deploy hooks (`git submodule add https://github.com/markomarkovic/simple-php-git-deploy.git deploy-hooks`)
1) Create a *strong* `SECRET_ACCESS_TOKEN` (`sed "s/[^a-zA-Z0-9]//g" <<<$(openssl rand -base64 128) | head -c 65`)
1) Create the `deploy-hooks/deploy-config.php` file (see `deploy-config.example.php` for full docs) - use the `SECRET_ACCESS_TOKEN` created above
1) Create reasonable `.gitignore` and `.htaccess` files; examples below:
    ### `.gitignore`
    ```
    .idea/
    VERSION
    **/deploy-config.php
    ```
    ### `.htaccess`
    ```
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
    ```
1) Add all the files, and push your code (`git add ./ && git commit && git push -u origin main`)
1) Configure a webhook at `https://github.com/<GH_USERNAME>/<DOMAIN>/settings/hooks`
    1) **Payload URL:** `https://<DOMAIN>/deploy-hooks/deploy.php?sat=<SECRET ACCESS TOKEN FROM DEPLOY-CONFIG.PHP>`
    1) **Content Type:** `application/x-www-form-urlencoded`
    1) **Secret:** *EMPTY*
    1) **SSL verification:** `Enable SSL Verification`
    1) **Which events would you like to trigger this webhook?:** `Just the push event`
    1) **Active:** *Check*
1) SSH to your remote host, and checkout your repo (use the `git clone --recurse-submodules git@github.com:<GH_USERNAME>/<DOMAIN>.git ~/<DOMAIN>`)
1) Copy the `deploy-hooks/deploy-config.php` you created above over to your remote host directory `~/<DOMAIN>/deploy-hooks/deploy-config.php`
1) Create the `~/<DOMAIN>_backups` on your remote host
1) Profit.

You should now be able to push commits to this git repo and have your domain automatically pull the changes.