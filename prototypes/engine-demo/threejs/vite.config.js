// PROTOTYPE — serves the shared ../assets folder as the web root for assets.
export default { publicDir: '../assets', server: { fs: { allow: ['..'] } } };
