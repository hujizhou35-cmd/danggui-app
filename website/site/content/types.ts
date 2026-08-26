export const locales = ['zh-CN', 'en', 'ja', 'ru'] as const;

export type Locale = (typeof locales)[number];

export interface Feature {
  id: string;
  title: string;
  description: string;
  image: string;
  alt: string;
}

export interface Story {
  id: string;
  title: string;
  excerpt: string;
  body: string;
  image: string;
  alt: string;
  productTheme: string;
}

export interface NarrativeContent {
  locale: Locale;
  characterName: string;
  hero: {
    title: string;
    description: string;
    image: string;
    alt: string;
  };
  features: Feature[];
  stories: Story[];
}

export interface UiCopy {
  localeName: string;
  shortLocale: string;
  skipLink: string;
  brandAria: string;
  metaDescription: string;
  nav: {
    features: string;
    stories: string;
    download: string;
    privacy: string;
    support: string;
    github: string;
    menu: string;
    language: string;
  };
  common: {
    preRelease: string;
    stableRelease: string;
    currentPublicRelease: string;
    releaseUnavailable: string;
    publishedOn: string;
    readStory: string;
    viewAllStories: string;
    backToStories: string;
    previousStory: string;
    nextStory: string;
    openNewWindow: string;
  };
  home: {
    promise: string;
    primaryCta: string;
    secondaryCta: string;
    releaseNote: string;
    previewEyebrow: string;
    previewTitle: string;
    previewDescription: string;
    previewAlt: string;
    showcaseCapture: string;
    showcaseItems: Array<{ title: string; body: string }>;
    featuresEyebrow: string;
    featuresTitle: string;
    storiesEyebrow: string;
    storiesTitle: string;
    storiesDescription: string;
    privacyEyebrow: string;
    privacyTitle: string;
    privacyDescription: string;
    privacyPoints: string[];
    downloadEyebrow: string;
    downloadTitle: string;
    downloadDescription: string;
    androidCta: string;
    iosCta: string;
    sectionNav: {
      label: string;
      show: string;
      hide: string;
      items: {
        top: string;
        preview: string;
        features: string;
        stories: string;
        privacy: string;
        download: string;
      };
    };
  };
  stories: {
    eyebrow: string;
    title: string;
    intro: string;
    detailEyebrow: string;
    relatedTitle: string;
  };
  download: {
    eyebrow: string;
    title: string;
    intro: string;
    androidTitle: string;
    androidBody: string;
    androidRecommended: string;
    releaseCta: string;
    androidCta: string;
    checksumTitle: string;
    checksumBody: string;
    checksumCta: string;
    iosTitle: string;
    sourceLabel: string;
    iosBody: string;
    iosWarning: string;
    iosCta: string;
    iosGuideCta: string;
    previewAvailable: string;
    previewCta: string;
    allReleasesCta: string;
    beforeTitle: string;
    beforeItems: string[];
  };
  privacy: {
    eyebrow: string;
    proofEyebrow: string;
    title: string;
    intro: string;
    principles: Array<{ title: string; body: string }>;
    policyEyebrow: string;
    policyTitle: string;
    policyUpdated: string;
    controllerTitle: string;
    controllerBody: string;
    policySections: Array<{ title: string; body: string }>;
    proofTitle: string;
    proofBody: string;
    proofCta: string;
    siteTitle: string;
    siteBody: string;
    contactCta: string;
  };
  support: {
    eyebrow: string;
    title: string;
    intro: string;
    contactEyebrow: string;
    contactTitle: string;
    contactBody: string;
    emailCta: string;
    issuesCta: string;
    downloadCta: string;
    warningTitle: string;
    warningBody: string;
    faqEyebrow: string;
    faqTitle: string;
    faqs: Array<{ question: string; answer: string }>;
  };
  footer: {
    tagline: string;
    source: string;
    license: string;
    trademark: string;
    status: string;
  };
}
