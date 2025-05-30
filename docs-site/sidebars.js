// @ts-check

// This runs in Node.js - Don't use client-side code here (browser APIs, JSX...)

/**
 * Creating a sidebar enables you to:
 - create an ordered group of docs
 - render a sidebar for each doc of that group
 - provide next/previous navigation

 The sidebars can be generated from the filesystem, or explicitly defined here.

 Create as many sidebars as you want.

 @type {import('@docusaurus/plugin-content-docs').SidebarsConfig}
 */
const sidebars = {
  // Manual sidebar with organized categories
  tutorialSidebar: [
    // Getting Started
    'index',
    'getting-started',
    
    // 🔐 Security & Authentication (NEW in 0.5.0)
    'authentication',
    
    'crud',  // ⚡ CRUD Operations - Quick Start Feature
    
    // Core Concepts
    {
      type: 'category',
      label: '🏗️ Core Framework',
      items: [
        'routing',
        'requests',
        'responses',
        'response_factory',
        'validation',
      ],
    },
    
    // Dependency Injection
    {
      type: 'category',
      label: '🔧 Dependency Injection',
      items: [
        'dependency-injection',
        'di-examples',
      ],
    },
    
    // Database Integration
    {
      type: 'category',
      label: '🗄️ Database Integration',
      items: [
        'database-integration',
        'repositories',
        'query-methods',
      ],
    },
    
    // Utilities & Advanced
    {
      type: 'category',
      label: '🛠️ Utilities & Advanced',
      items: [
        'json',
        'examples',
      ],
    },
  ],
};

export default sidebars;
