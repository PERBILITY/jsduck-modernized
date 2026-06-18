/**
 * The same kind of ExtJS class, but written with MODERN JavaScript that
 * the old RKelly front-end cannot parse (and which today forces the Babel
 * workaround). With the acorn front-end this should parse directly and the
 * documented source shown in the UI is this original, un-transpiled code.
 *
 * Modern syntax exercised: const/let, arrow functions, template literals,
 * shorthand methods, default params, async/await, spread.
 */
Ext.define('Poc.ModernWidget', {
    extend: 'Ext.Component',

    mixins: {
        observable: 'Ext.util.Observable'
    },

    statics: {
        /**
         * @property {String} TYPE The widget type identifier.
         * @readonly
         */
        TYPE: 'modern',

        /**
         * Builds several widgets at once.
         * @param {Object[]} configs
         * @return {Poc.ModernWidget[]}
         * @static
         */
        fromAll(configs = []) {
            return configs.map(cfg => new Poc.ModernWidget({ ...cfg }));
        }
    },

    config: {
        /**
         * @cfg {String} title The widget title.
         */
        title: '',

        /**
         * @cfg {Number} [width=100] The widget width in pixels.
         */
        width: 100
    },

    /**
     * @event titlechange Fires when the title changes.
     * @param {Poc.ModernWidget} this
     * @param {String} title The new title.
     */

    /**
     * Applies the title config.
     * @param {String} title
     * @return {String}
     */
    applyTitle(title) {
        const normalized = title ?? '';
        return `${normalized}`;
    },

    /**
     * Loads the title from a remote source.
     * @async
     * @param {String} url
     * @return {Promise}
     */
    async loadTitle(url) {
        const response = await fetch(url);
        const data = await response.json();
        this.setTitle(data.title);
    },

    /**
     * Reacts to title updates.
     * @param {String} title
     * @param {String} oldTitle
     */
    updateTitle(title, oldTitle) {
        this.fireEvent('titlechange', this, title);
    }
});
