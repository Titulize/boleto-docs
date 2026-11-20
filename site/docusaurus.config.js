// @ts-check
import { themes as prismThemes } from 'prism-react-renderer';

/** @type {import('@docusaurus/types').Config} */
const config = {
  title: 'Plataforma de Boletos',
  tagline: 'Remessa e retorno CNAB, com documentação viva',
  favicon: 'img/favicon.svg',

  url: 'https://titulize.github.io',
  baseUrl: '/boleto-docs/',
  organizationName: 'Titulize',
  projectName: 'boleto-docs',
  trailingSlash: false,

  onBrokenLinks: 'throw',
  onBrokenAnchors: 'throw',

  markdown: {
    mermaid: true,
    hooks: {
      onBrokenMarkdownLinks: 'throw',
    },
  },
  themes: ['@docusaurus/theme-mermaid'],

  i18n: {
    defaultLocale: 'pt-BR',
    locales: ['pt-BR'],
  },

  presets: [
    [
      'classic',
      /** @type {import('@docusaurus/preset-classic').Options} */
      ({
        docs: {
          routeBasePath: '/',
          sidebarPath: './sidebars.js',
          editUrl: 'https://github.com/Titulize/boleto-docs/edit/main/site/',
        },
        blog: false,
        theme: {
          customCss: './src/css/custom.css',
        },
      }),
    ],
  ],

  themeConfig:
    /** @type {import('@docusaurus/preset-classic').ThemeConfig} */
    ({
      navbar: {
        title: 'Plataforma de Boletos',
        items: [
          { type: 'docSidebar', sidebarId: 'main', position: 'left', label: 'Documentação' },
          { href: 'https://github.com/Titulize/boleto-docs', label: 'GitHub', position: 'right' },
        ],
      },
      footer: {
        style: 'dark',
        copyright: `Titulize. Documentação mantida junto ao código.`,
      },
      prism: {
        theme: prismThemes.github,
        darkTheme: prismThemes.dracula,
        additionalLanguages: ['java', 'kotlin', 'bash', 'powershell', 'sql', 'toml', 'yaml', 'docker'],
      },
      mermaid: {
        theme: { light: 'neutral', dark: 'dark' },
      },
    }),
};

export default config;
