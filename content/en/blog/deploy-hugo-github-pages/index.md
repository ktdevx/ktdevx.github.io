---
title: Publish a Static Website with Hugo and GitHub Pages
date: 2024-09-27T21:11:39+09:00
draft: false
params:
  pager: true
  toc: true
---

Using Hugo and GitHub Pages, you can easily publish a static website. Here, I will explain the steps.

## Create a Repository for the Website on GitHub

Create a repository on GitHub with any name. For details, refer to [this guide](/blog/create-github-repository).

If you name the repository `<username>.github.io`, your website will be published at `https://<username>.github.io/`. If your account name contains uppercase letters, you need to convert them to lowercase.

If you create a repository with a different name, the URL for your website will be `https://<username>.github.io/<repository-name>`.

If you are using GitHub Free, you must set the repository to public.

After creating the repository, clone it to your local environment.

## Set Up Hugo

Navigate to the cloned repository and run `hugo new site . --force`. This command creates Hugo's directory structure within the directory. Since the directory is not empty, we use the `--force` option.

## Edit the Hugo Configuration File

Once the Hugo setup is complete, a configuration file named `hugo.toml` is generated.

```toml
baseURL = 'https://example.org/'
languageCode = 'en-us'
title = 'My New Hugo Site'
```

Modify the basic settings.

- baseURL  
  Specify the URL where the website will be published. This depends on the repository name.
- languageCode  
  Specify the language for the website.
- title  
  Set the title of the website. 

In this example, the settings were changed as follows:

```toml
baseURL = 'https://ktdevx.github.io/'
languageCode = 'ja'
title = 'KTDEVX'
```

For more details about the configuration, refer to the [official documentation](https://gohugo.io/getting-started/configuration/).

## Add a Theme to the Project

Add a theme to the project from the [official Hugo theme site](https://themes.gohugo.io/).

In this case, we'll use the [Ananke](https://github.com/theNewDynamic/gohugo-theme-ananke) theme. Run the following command to add Ananke to the project using Git Submodules.

```
git submodule add https://github.com/theNewDynamic/gohugo-theme-ananke.git themes/ananke
```

To apply the theme, add `theme = 'ananke'` to `hugo.toml`.

## Add a Page

Next, create actual content. Run the following command to create a new post.

```
hugo new content/posts/hello-world.md
Edit the generated hello-world.md file and write the article.
```

```markdown
+++
title = 'Hello, World!'
date = 2024-09-19T00:00:00+09:00
draft = true
+++

This is my first blog post created with Hugo.
```

One thing to note here is the `draft = true` setting, which indicates that the post is in draft mode.

To publish the article, set `draft = false` or remove the `draft` setting.

## Preview the Website Locally

Start a local server and preview the site using the following command:

```
hugo server -D
```

The `-D` option is used to display draft posts. Open your browser and navigate to `http://localhost:1313/` to preview the site.

If everything looks good, disable the draft setting for the post and push it to the remote repository.

## Configure Deployment with GitHub Pages

Go to the "Settings" of the GitHub repository, click on "Pages," and enable GitHub Pages. In this case, we will deploy using GitHub Actions. Set "Source" to "GitHub Actions."

## Create a Workflow for Build and Deployment

Add a workflow for building and deploying the website to the project. Create a `gh-pages.yml` file in the `.github/workflows/` directory and write the following

```yaml
name: GitHub Pages

on:
  push:
    branches:
      - main

jobs:
  build:
    runs-on: ubuntu-22.04
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          submodules: recursive
      - name: Install Hugo
        env:
          HUGO_VERSION: "0.134.3"
        run: |
          wget -q -O ${{ runner.temp }}/hugo.tar.gz https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz
          tar -xzf ${{ runner.temp }}/hugo.tar.gz -C ${{ runner.temp }}
          sudo mv ${{ runner.temp }}/hugo /usr/local/bin/
          hugo version
      - name: Build with Hugo
        run: hugo --minify
      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: public/

  deploy:
    needs: build
    runs-on: ubuntu-22.04
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    permissions:
      pages: write
      id-token: write
    steps:
      - name: Deploy to GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v4
```

With this setup, every time you push to the `main` branch, the website will automatically be built and deployed.

## Check the Published Website

Open a browser and visit `https://<username>.github.io/` or `https://<username>.github.io/<repository-name>` to verify that your website is live.
