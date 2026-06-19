/**
 * A representative ExtJS class exercising the features JSDuck understands:
 * extend, mixins, statics, config (cfg), events, apply/update methods.
 *
 * This file uses only ES5 syntax, so it parses with BOTH the RKelly and
 * the acorn front-end -- use it to confirm the acorn output is equivalent.
 */
Ext.define('Poc.ClassicWidget', {
    extend: 'Ext.Component',

    mixins: {
        observable: 'Ext.util.Observable'
    },

    requires: ['Poc.util.Helper'],

    statics: {
        /**
         * @property {String} TYPE The widget type identifier.
         * @readonly
         */
        TYPE: 'classic',

        /**
         * Creates a widget from config.
         * @param {Object} cfg
         * @return {Poc.ClassicWidget}
         * @static
         */
        from: function(cfg) {
            return new Poc.ClassicWidget(cfg);
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
     * @param {Poc.ClassicWidget} this
     * @param {String} title The new title.
     */

    /**
     * Applies the title config.
     * @param {String} title
     * @return {String}
     */
    applyTitle: function(title) {
        return title == null ? '' : String(title);
    },

    /**
     * Reacts to title updates.
     * @param {String} title
     * @param {String} oldTitle
     */
    updateTitle: function(title, oldTitle) {
        // a plain comment inside a method body
        this.fireEvent('titlechange', this, title);
    }
});
